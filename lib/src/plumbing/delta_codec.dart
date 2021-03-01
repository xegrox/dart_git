import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_vlq_codec.dart';

class GitDeltaCodec {
  final _vlqCodec = GitVLQCodec(offset: false, endian: Endian.little);

  Uint8List decode(Uint8List baseObjContent, ByteDataReader reader) {
    if (reader.endian != Endian.big) throw GitException('Reader endianness must be big');
    var baseObjSize = _vlqCodec.decode(reader);
    if (baseObjSize != baseObjContent.length) throw GitDeltaException('Invalid base object size $baseObjSize');
    var objSize = _vlqCodec.decode(reader);

    var objContent = <int>[];
    while (reader.remainingLength != 0) {
      var opcode = reader.readUint8();
      if (opcode & 0x80 != 0) {
        // Instruction to copy from base object
        var offset = 0;
        var size = 0;

        // Read offset
        if (opcode & 0x01 != 0) offset |= reader.readUint8();
        if (opcode & 0x02 != 0) offset |= reader.readUint8() << 8;
        if (opcode & 0x04 != 0) offset |= reader.readUint8() << 16;
        if (opcode & 0x08 != 0) offset |= reader.readUint8() << 24;

        // Read size
        if (opcode & 0x10 != 0) size |= reader.readUint8();
        if (opcode & 0x20 != 0) size |= reader.readUint8() << 8;
        if (opcode & 0x40 != 0) size |= reader.readUint8() << 16;
        if (size == 0) size = 0x10000;

        var copyContent = baseObjContent.getRange(offset, offset + size);
        objContent.addAll(copyContent);
      } else if (opcode & 0x80 == 0 && opcode != 0) {
        // Instruction to add new data
        var size = opcode;
        var content = reader.read(size);
        objContent.addAll(content);
      } else {
        throw GitDeltaException('Invalid delta opcode $opcode');
      }
    }

    if (objSize != objContent.length) {
      throw GitDeltaException('Generated object size does not match actual size');
    }

    return Uint8List.fromList(objContent);
  }
}
