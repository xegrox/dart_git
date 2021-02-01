import 'dart:math';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dart_git/src/git_vlq_codec.dart';
import 'package:test/test.dart';

void main() {

  Uint8List binaryToUnit8List(String binaryString) {
    List<int> decimalList = [];
    var byteBinaryList = binaryString.replaceAll(' ', '').split('');
    if (byteBinaryList.length.remainder(8) != 0) throw Exception('Binary length must be a factor of 8, but was ${byteBinaryList.length}');

    // Iterate through byte by byte
    for (var i = 0; i < byteBinaryList.length; i += 8) {
      var decimal = 0;
      byteBinaryList.getRange(i, i+8).toList().reversed.toList().asMap().forEach((index, bitString) { // This is stupid
        var bit = int.parse(bitString);
        decimal += bit * pow(2, index);
      });
      decimalList.add(decimal);
    }
    return Uint8List.fromList(decimalList);
  }

  test('Test git vlq encode', () {
    var vlqCodec = GitVLQCodec();

    var encoded_1 = vlqCodec.encode(0); // Min of 1-octet
    var encoded_2 = vlqCodec.encode(127); // Max of 1-octet
    var encoded_3 = vlqCodec.encode(128); // Min of 2-octet
    var encoded_4 = vlqCodec.encode(16511); // Max of 2-octet
    var encoded_5 = vlqCodec.encode(16512); // Min of 3-octet
    var encoded_6 = vlqCodec.encode(2113663); // Max of 3-octet

    expect(encoded_1, binaryToUnit8List('0000 0000'));
    expect(encoded_2, binaryToUnit8List('0111 1111'));
    expect(encoded_3, binaryToUnit8List('1000 0000 0000 0000'));
    expect(encoded_4, binaryToUnit8List('1111 1111 0111 1111'));
    expect(encoded_5, binaryToUnit8List('1000 0000 1000 0000 0000 0000'));
    expect(encoded_6, binaryToUnit8List('1111 1111 1111 1111 0111 1111'));

    var reader = ByteDataReader();
    reader.add(encoded_1);
    reader.add(encoded_2);
    reader.add(encoded_3);
    reader.add(encoded_4);
    reader.add(encoded_5);
    reader.add(encoded_6);

    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 127);
    expect(vlqCodec.decode(reader), 128);
    expect(vlqCodec.decode(reader), 16511);
    expect(vlqCodec.decode(reader), 16512);
    expect(vlqCodec.decode(reader), 2113663);
  });
}