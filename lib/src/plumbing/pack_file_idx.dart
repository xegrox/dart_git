import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';

class GitPackFileIdxEntry {
  final GitHash hash;
  final int crc32;
  final int offset;

  GitPackFileIdxEntry({required this.hash, required this.crc32, required this.offset});
}

class GitPackFileIdx {
  static const _signature = 0xff744f63; // \377tOc
  static const _fanTableLength = 256;

  final Uint32List fanTable;
  final List<GitPackFileIdxEntry> entries;
  final GitHash packFileHash;

  GitPackFileIdx._(this.fanTable, this.entries, this.packFileHash);

  factory GitPackFileIdx.fromBytes(Uint8List data) {
    var reader = ByteDataReader();
    reader.add(data);
    var sig = reader.readUint32();
    if (sig != _signature) {
      throw GitPackIdxFileException('Invalid signature $sig');
    }
    var version = reader.readUint32();
    if (version != 2) {
      throw GitPackIdxFileException('Version "$version" is unsupported; Only version 2 is supported');
    }

    // Fan-out Table
    // The ith entry, F[i], stores the number of OIDs with first
    // byte at most i. Thus F[255] stores the total
    // number of objects.
    var fanTable = Uint32List(_fanTableLength);
    for (var i = 0; i < _fanTableLength; i++) {
      fanTable[i] = reader.readUint32();
    }
    var numObjects = fanTable.last;

    // Read Hashes
    var hashes = <GitHash>[];
    for (var i = 0; i < numObjects; i++) {
      var hash = GitHash.fromBytes(reader.read(20));
      hashes.add(hash);
    }

    // Read crc32
    // TODO: support crc
    var crcValues = <int>[];
    for (var i = 0; i < numObjects; i++) {
      crcValues.add(reader.readUint32());
    }

    // Read offsets
    var offsets = <int>[];
    var offsets64BitPos = <int>[];
    for (var i = 0; i < numObjects; i++) {
      var d = reader.readUint32();
      var mask = 0x01 << 31;
      var msb = d & mask;
      offsets.add(d & ~mask);
      if (msb == 1) offsets64BitPos.add(i);
    }

    offsets64BitPos.forEach((pos) {
      offsets[pos] = reader.readUint64();
    });

    // Trailer
    var packFileHash = GitHash.fromBytes(reader.read(20));
    var numBytes = reader.offsetInBytes;
    var packIdxFileHash = GitHash.fromBytes(reader.read(20));
    var cPackIdxFileHash = GitHash.compute(data.sublist(0, numBytes));
    if (cPackIdxFileHash != packIdxFileHash) {
      throw GitPackIdxFileException('Invalid file hash $packIdxFileHash');
    }

    var entries = <GitPackFileIdxEntry>[];
    for (var i = 0; i < numObjects; i++) {
      var entry = GitPackFileIdxEntry(hash: hashes[i], crc32: crcValues[i], offset: offsets[i]);
      entries.add(entry);
    }

    return GitPackFileIdx._(fanTable, entries, packFileHash);
  }

  int getOffset(GitHash hash) {
    var exception = GitPackIdxFileException('Unknown object hash');
    var firstHashByte = hash.bytes[0];
    var objIndex = fanTable[firstHashByte] - 1;
    if (objIndex < 0) throw exception;
    var prevObjIndex = fanTable[firstHashByte - 1] - 1;
    if (prevObjIndex != objIndex - 1) {
      // More than 1 oids with the same first byte
      var e = entries.sublist(prevObjIndex + 1, objIndex + 1); // List of entries with same first byte
      for (var i = 0; i < e.length; i++) {
        if (e[i].hash == hash) return e[i].offset;
      }
      ;
      throw exception;
    } else {
      if (hash != entries[objIndex].hash) throw exception;
      return entries[objIndex].offset;
    }
  }
}
