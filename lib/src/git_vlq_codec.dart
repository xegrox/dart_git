import 'dart:math';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/src/exceptions.dart';

// ReadVariableWidthInt reads and returns an int in Git VLQ special format:
//
// Ordinary VLQ has some redundancies, example:  the number 358 can be
// encoded as the 2-octet VLQ 0x8166 or the 3-octet VLQ 0x808166 or the
// 4-octet VLQ 0x80808166 and so forth.
//
// To avoid these redundancies, the VLQ format used in Git removes this
// prepending redundancy and extends the representable range of shorter
// VLQs by adding an offset to VLQs of 2 or more octets in such a way
// that the lowest possible value for such an (N+1)-octet VLQ becomes
// exactly one more than the maximum possible value for an N-octet VLQ.
// In particular, since a 1-octet VLQ can store a maximum value of 127,
// the minimum 2-octet VLQ (0x8000) is assigned the value 128 instead of
// 0. Conversely, the maximum value of such a 2-octet VLQ (0xff7f) is
// 16511 instead of just 16383. Similarly, the minimum 3-octet VLQ
// (0x808000) has a value of 16512 instead of zero, which means
// that the maximum 3-octet VLQ (0xffff7f) is 2113663 instead of
// just 2097151.  And so forth.
//
// This is how the offset is saved in C:
//
//     dheader[pos] = ofs & 127;
//     while (ofs >>= 7)
//         dheader[--pos] = 128 | (--ofs & 127);
//

class GitVLQCodec {
  final bool offset;
  final Endian endian;

  GitVLQCodec({this.offset = true, this.endian = Endian.big});

  final _maskContinue = int.parse('10000000', radix: 2);
  final _maskLength = int.parse('01111111', radix: 2);
  final _lengthBits = 7;

  int decode(ByteDataReader reader) {
    if (reader.endian != Endian.big) throw GitException('Reader endianness must be big');
    var byte = reader.readUint8();
    var data = (byte & _maskLength);
    var numberOfBytes = 1;
    var offset = 0;

    while ((byte & _maskContinue) > 0) {
      numberOfBytes++;
      // If continue flag is 1, read the next byte
      byte = reader.readUint8();
      // Append 7 bits then add the new 7 bits
      var d = byte & _maskLength;
      if (endian == Endian.big) {
        data = (data << _lengthBits) | d;
      } else if (endian == Endian.little) {
        data = data | (d << _lengthBits * (numberOfBytes - 1));
      }
      // Calculate offset
      if (this.offset) offset += (pow(2, _lengthBits * (numberOfBytes - 1))).toInt();
    }
    return data + offset;
  }

  Uint8List encode(int num) {
    if (num < 0) throw UnimplementedError('Encoding of negative integers is not supported');

    // Calculate offset and number of bytes for the vlq
    var maxValue = pow(2, 7).toInt(); // Zero inclusive
    var numberOfBytes = 1;
    var offset = 0;
    while (num > (maxValue - 1)) {
      if (this.offset) offset = maxValue;
      maxValue *= pow(2, 7).toInt();
      maxValue += offset;
      numberOfBytes++;
    }

    var genNum = num - offset; // Number exclusive of offset

    // Calculate padding
    var paddingLength = _lengthBits - (genNum.bitLength % 7);
    if (paddingLength == 7) paddingLength = 0; // No padding is needed if all 7 bits are used

    // Encode data
    var mask = 0x7f;
    mask >>= paddingLength;
    mask <<= (genNum.bitLength - mask.bitLength).abs(); // Start from most significant bit

    var encodedData = <int>[];
    for (var i = 1; i <= numberOfBytes; i++) {
      // Read in big-endian order
      var data = (genNum & mask); // Get next set of bits
      data >>= (mask.bitLength - _lengthBits.abs()); // Trim trailing bits

      mask >>= data.bitLength; // Shorten mask length
      mask &= _maskLength << (mask.bitLength - _lengthBits).abs(); // Set most significant 7 bits

      if (endian == Endian.big) {
        var continueBit = (i < numberOfBytes) ? 1 : 0;
        data |= continueBit << _lengthBits;
        encodedData.add(data);
      } else if (endian == Endian.little) {
        var continueBit = (i == 1) ? 0 : 1;
        data |= continueBit << _lengthBits;
        encodedData.insert(0, data);
      }
    }

    return Uint8List.fromList(encodedData);
  }
}
