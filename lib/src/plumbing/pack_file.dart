import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_vlq_codec.dart';
import 'package:dart_git/src/plumbing/delta_codec.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

abstract class GitPackObjectId {
  static const commit = 1;
  static const tree = 2;
  static const blob = 3;
  static const tag = 4;
  static const ofs_delta = 6;
  static const ref_delta = 7;
}

class GitPackFileEntry {
  final int offset;
  final int type;
  final int size;
  final Uint8List content;

  final GitPackFileEntry? baseObjEntry;

  static final _vlqCodec = GitVLQCodec(offset: false, endian: Endian.little);

  GitPackFileEntry._(this.offset, this.type, this.size, this.content, this.baseObjEntry);

  factory GitPackFileEntry.fromBytes(Uint8List data, int offset) {
    var reader = ByteDataReader();
    reader.add(data.sublist(offset - 12)); // Don't account for 12 byte pack file header
    var header = _vlqCodec.decode(reader);
    // [size...][(3)type][(4)size]
    var type = (header & 0x70) >> 4;
    if (type < 1 || type > 7 || type == 5) throw GitPackFileException('Invalid object type \'$type\'');
    var size = ((header >> 7) << 4) | (header & 0x0f);

    GitPackFileEntry? baseObj;
    switch (type) {
      case GitPackObjectId.ref_delta:
        //var baseObjHash = GitHash.fromBytes(reader.read(20));
        // TODO: parse ref delta
        throw UnimplementedError();
      case GitPackObjectId.ofs_delta:
        var n = GitVLQCodec(offset: true, endian: Endian.big).decode(reader);
        var baseObjOffset = offset - n;
        baseObj = GitPackFileEntry.fromBytes(data, baseObjOffset);
        break;
    }

    var decodedData = zlib.decode(reader.read(reader.remainingLength));
    return GitPackFileEntry._(offset, type, size, Uint8List.fromList(decodedData), baseObj);
  }
}

class GitPackFile {
  static final _signature = 'PACK';
  final int version;
  final int numObjects;
  final Uint8List _entriesData;

  GitPackFile._(this.version, this.numObjects, this._entriesData);

  factory GitPackFile.fromBytes(Uint8List data) {
    var reader = ByteDataReader();
    reader.add(data);
    var sig = ascii.decode(reader.read(4));
    if (sig != _signature) {
      throw GitPackFileException('Invalid signature $sig');
    }
    var version = reader.readUint32();
    if (version < 2 || version > 3) {
      throw GitPackFileException('Version "$version" is unsupported; Only versions 2 and 3 are supported');
    }
    var numObjects = reader.readUint32();
    var entriesData = reader.read(reader.remainingLength);
    return GitPackFile._(version, numObjects, entriesData);
  }

  GitObject getObject(int offset) {
    var entry = GitPackFileEntry.fromBytes(_entriesData, offset);
    switch (entry.type) {
      case GitPackObjectId.commit:
        return GitCommit.fromBytes(entry.content);
      case GitPackObjectId.tree:
        return GitTree.fromBytes(entry.content);
      case GitPackObjectId.blob:
        return GitBlob.fromBytes(entry.content);
      case GitPackObjectId.ofs_delta:
        var baseObj = getObject(entry.baseObjEntry!.offset);
        var baseObjContent = baseObj.serializeContent();
        var reader = ByteDataReader();
        reader.add(entry.content);
        Uint8List content;
        try {
          content = GitDeltaCodec().decode(baseObjContent, reader);
        } on GitException catch (e) {
          throw GitPackFileException('Corrupt delta: ${e.message}');
        }
        switch (baseObj.signature) {
          case GitObjectSignature.commit:
            return GitCommit.fromBytes(content);
          case GitObjectSignature.tree:
            return GitTree.fromBytes(content);
          case GitObjectSignature.blob:
            return GitBlob.fromBytes(content);
        }
        break;
      case GitPackObjectId.ref_delta:
        throw UnimplementedError();
    }
    throw GitPackFileException('Invalid entry object type ${entry.type}');
  }
}
