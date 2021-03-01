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

  List<int> _intToBinary(int num) {
    var data = <int>[];
    var binaryString = num.toRadixString(2);
    binaryString.split('').forEach((bitString) {
      data.add(int.parse(bitString));
    });
    return data;
  }

  int _binaryToInt(List<int> binaryList) {
    var number = 0;
    if (binaryList.length != 8) throw Exception('Binary length must be 8, but was ${binaryList.length}');
    var byteInBinary = binaryList.reversed.toList();
    byteInBinary.asMap().forEach((index, bit) {
      number += (bit * pow(2, index)).toInt();
    });
    return number;
  }

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
    var encodedData = <int>[];

    // Calculate offset and number of bytes
    var maxValue = pow(2, 7); // Minus 1 to get the actual max value
    var numberOfBytes = 1;
    var offset = 0;
    while (num > (maxValue - 1)) {
      if (this.offset) offset += (pow(2, _lengthBits * (numberOfBytes))).toInt();
      maxValue *= pow(2, 7);
      maxValue += offset;
      numberOfBytes++;
    }

    var reader = ByteDataReader();
    var bytes = _intToBinary(num - offset);
    reader.add(bytes);

    // Calculate padding
    var padding = <int>[];
    var paddingCount = (_lengthBits - reader.remainingLength.remainder(_lengthBits)).toInt();
    if (paddingCount == 7) paddingCount = 0; // No padding is needed if all 7 bits are used
    for (var i = 1; i <= paddingCount; i++) {
      padding.add(0);
    }

    // Encode data
    for (var i = 1; i <= numberOfBytes; i++) {
      List<int> data;
      if (reader.remainingLength != 0) {
        data = reader.read(_lengthBits - paddingCount);
      } else {
        // Add zero bits if all the bits have been read
        data = [0, 0, 0, 0, 0, 0, 0];
      }
      if (endian == Endian.big) {
        var continueBit = (i < numberOfBytes) ? 1 : 0;
        var byteInDecimal = _binaryToInt([continueBit] + padding + data);
        encodedData.add(byteInDecimal);
      } else if (endian == Endian.little) {
        var continueBit = (i == 1) ? 0 : 1;
        var byteInDecimal = _binaryToInt([continueBit] + padding + data);
        encodedData.insert(0, byteInDecimal);
      }
      // Clear the padding after the first octet is added
      paddingCount = 0;
      padding = [];
    }

    return Uint8List.fromList(encodedData);
  }
}
