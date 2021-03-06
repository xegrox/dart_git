import 'dart:math';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:test/test.dart';

import 'package:dart_git/src/git_vlq_codec.dart';

void main() {
  Uint8List binaryToUnit8List(String binaryString) {
    var decimalList = <int>[];
    var trimmedString = binaryString.replaceAll(' ', '');

    var bitLen = 8 - (trimmedString.length % 8);
    if (bitLen == 8) bitLen = 0;
    bitLen += trimmedString.length;
    var byteBinaryList = trimmedString.padLeft(bitLen, '0').split('');

    // Iterate through byte by byte
    for (var i = 0; i < byteBinaryList.length; i += 8) {
      var decimal = 0;
      var bIndex = 0;
      byteBinaryList.sublist(i, i + 8).reversed.toList().forEach((bitString) {
        var bit = int.parse(bitString);
        decimal += (bit * pow(2, bIndex)).toInt();
        bIndex++;
      });
      decimalList.add(decimal);
    }
    return Uint8List.fromList(decimalList);
  }

  test('Test git vlq codec [offset, big endian]', () {
    var vlqCodec = GitVLQCodec(offset: true, endian: Endian.big);

    var encoded_1 = vlqCodec.encode(0); // Min of 1-octet
    var encoded_2 = vlqCodec.encode(127); // Max of 1-octet
    var encoded_3 = vlqCodec.encode(128); // Min of 2-octet
    var encoded_4 = vlqCodec.encode(16511); // Max of 2-octet
    var encoded_5 = vlqCodec.encode(16512); // Min of 3-octet
    var encoded_6 = vlqCodec.encode(2113663); // Max of 3-octet
    var encoded_7 = vlqCodec.encode(8192 + 128);

    expect(encoded_1, binaryToUnit8List('0000 0000'));
    expect(encoded_2, binaryToUnit8List('0111 1111'));
    expect(encoded_3, binaryToUnit8List('1000 0000 0000 0000'));
    expect(encoded_4, binaryToUnit8List('1111 1111 0111 1111'));
    expect(encoded_5, binaryToUnit8List('1000 0000 1000 0000 0000 0000'));
    expect(encoded_6, binaryToUnit8List('1111 1111 1111 1111 0111 1111'));
    expect(encoded_7, binaryToUnit8List('1100 0000 0000 0000'));

    var reader = ByteDataReader();
    reader.add(encoded_1);
    reader.add(encoded_2);
    reader.add(encoded_3);
    reader.add(encoded_4);
    reader.add(encoded_5);
    reader.add(encoded_6);
    reader.add(encoded_7);

    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 127);
    expect(vlqCodec.decode(reader), 128);
    expect(vlqCodec.decode(reader), 16511);
    expect(vlqCodec.decode(reader), 16512);
    expect(vlqCodec.decode(reader), 2113663);
    expect(vlqCodec.decode(reader), 8192 + 128);
  });

  test('Test git vlq codec [offset, little endian]', () {
    var vlqCodec = GitVLQCodec(offset: true, endian: Endian.little);

    var encoded_1 = vlqCodec.encode(0); // Min of 1-octet
    var encoded_2 = vlqCodec.encode(127); // Max of 1-octet
    var encoded_3 = vlqCodec.encode(128); // Min of 2-octet
    var encoded_4 = vlqCodec.encode(16511); // Max of 2-octet
    var encoded_5 = vlqCodec.encode(16512); // Min of 3-octet
    var encoded_6 = vlqCodec.encode(2113663); // Max of 3-octet
    var encoded_7 = vlqCodec.encode(8192 + 128);

    expect(encoded_1, binaryToUnit8List('0000 0000'));
    expect(encoded_2, binaryToUnit8List('0111 1111'));
    expect(encoded_3, binaryToUnit8List('1000 0000 0000 0000'));
    expect(encoded_4, binaryToUnit8List('1111 1111 0111 1111'));
    expect(encoded_5, binaryToUnit8List('1000 0000 1000 0000 0000 0000'));
    expect(encoded_6, binaryToUnit8List('1111 1111 1111 1111 0111 1111'));
    expect(encoded_7, binaryToUnit8List('1000 0000 0100 0000'));

    var reader = ByteDataReader();
    reader.add(encoded_1);
    reader.add(encoded_2);
    reader.add(encoded_3);
    reader.add(encoded_4);
    reader.add(encoded_5);
    reader.add(encoded_6);
    reader.add(encoded_7);

    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 127);
    expect(vlqCodec.decode(reader), 128);
    expect(vlqCodec.decode(reader), 16511);
    expect(vlqCodec.decode(reader), 16512);
    expect(vlqCodec.decode(reader), 2113663);
    expect(vlqCodec.decode(reader), 8192 + 128);
  });

  test('Test git vlq codec [no offset, big endian]', () {
    var vlqCodec = GitVLQCodec(offset: false, endian: Endian.big);

    var encoded_1 = vlqCodec.encode(0); // Min of 1-octet
    var encoded_2 = vlqCodec.encode(127); // Max of 1-octet
    var encoded_3 = vlqCodec.encode(0); // Min of 2-octet
    var encoded_4 = vlqCodec.encode(16383); // Max of 2-octet
    var encoded_5 = vlqCodec.encode(0); // Min of 3-octet
    var encoded_6 = vlqCodec.encode(2097151); // Max of 3-octet
    var encoded_7 = vlqCodec.encode(8192);

    expect(encoded_1, binaryToUnit8List('0000 0000'));
    expect(encoded_2, binaryToUnit8List('0111 1111'));
    expect(encoded_3, binaryToUnit8List('0000 0000'));
    expect(encoded_4, binaryToUnit8List('1111 1111 0111 1111'));
    expect(encoded_5, binaryToUnit8List('0000 0000'));
    expect(encoded_6, binaryToUnit8List('1111 1111 1111 1111 0111 1111'));
    expect(encoded_7, binaryToUnit8List('1100 0000 0000 0000'));

    var reader = ByteDataReader();
    reader.add(encoded_1);
    reader.add(encoded_2);
    reader.add(encoded_3);
    reader.add(encoded_4);
    reader.add(encoded_5);
    reader.add(encoded_6);
    reader.add(encoded_7);

    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 127);
    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 16383);
    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 2097151);
    expect(vlqCodec.decode(reader), 8192);
  });

  test('Test git vlq codec [no offset, little endian]', () {
    var vlqCodec = GitVLQCodec(offset: false, endian: Endian.little);

    var encoded_1 = vlqCodec.encode(0); // Min of 1-octet
    var encoded_2 = vlqCodec.encode(127); // Max of 1-octet
    var encoded_3 = vlqCodec.encode(0); // Min of 2-octet
    var encoded_4 = vlqCodec.encode(16383); // Max of 2-octet
    var encoded_5 = vlqCodec.encode(0); // Min of 3-octet
    var encoded_6 = vlqCodec.encode(2097151); // Max of 3-octet
    var encoded_7 = vlqCodec.encode(8192);

    expect(encoded_1, binaryToUnit8List('0000 0000'));
    expect(encoded_2, binaryToUnit8List('0111 1111'));
    expect(encoded_3, binaryToUnit8List('0000 0000'));
    expect(encoded_4, binaryToUnit8List('1111 1111 0111 1111'));
    expect(encoded_5, binaryToUnit8List('0000 0000'));
    expect(encoded_6, binaryToUnit8List('1111 1111 1111 1111 0111 1111'));
    expect(encoded_7, binaryToUnit8List('1000 0000 0100 0000'));

    var reader = ByteDataReader();
    reader.add(encoded_1);
    reader.add(encoded_2);
    reader.add(encoded_3);
    reader.add(encoded_4);
    reader.add(encoded_5);
    reader.add(encoded_6);
    reader.add(encoded_7);

    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 127);
    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 16383);
    expect(vlqCodec.decode(reader), 0);
    expect(vlqCodec.decode(reader), 2097151);
    expect(vlqCodec.decode(reader), 8192);
  });
}
