import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_vlq_codec.dart';

class GitIndexEntry {
  int version;
  GitTimestamp cTime;
  GitTimestamp mTime;
  int device;
  int inode;
  GitFileMode mode;
  int uid;
  int gid;
  int fileSize;
  GitHash hash;
  GitFileStage stage;
  String path;
  bool assumeValid;
  bool extended;
  bool skipWorkTree;
  bool intentToAdd;

  GitIndexEntry(
      {@required this.version,
      @required this.cTime,
      @required this.mTime,
      @required this.device,
      @required this.inode,
      @required this.mode,
      @required this.uid,
      @required this.gid,
      @required this.fileSize,
      @required this.hash,
      @required this.stage,
      @required this.path,
      this.assumeValid = false,
      this.extended = false,
      this.skipWorkTree = false,
      this.intentToAdd = false});

  GitIndexEntry.fromBytes(ByteDataReader reader, String previousEntryPath, int indexVersion) {
    version = indexVersion;

    var epochDateTime = DateTime.fromMillisecondsSinceEpoch(0);
    var cTimeSeconds = reader.readUint32();
    var cTimeNanoSeconds = reader.readUint32();
    var cTimeDateTime = epochDateTime.add(Duration(seconds: cTimeSeconds, microseconds: cTimeNanoSeconds ~/ 1000));
    cTime = GitTimestamp(dateTime: cTimeDateTime, seconds: cTimeSeconds, nanoSeconds: cTimeNanoSeconds);

    var mTimeSeconds = reader.readUint32();
    var mTimeNanoSeconds = reader.readUint32();
    var mTimeDateTime = epochDateTime.add(Duration(seconds: mTimeSeconds, microseconds: mTimeNanoSeconds ~/ 1000));
    mTime = GitTimestamp(dateTime: mTimeDateTime, seconds: mTimeSeconds, nanoSeconds: mTimeNanoSeconds);

    device = reader.readUint32();
    inode = reader.readUint32();
    mode = GitFileMode(reader.readUint32());
    uid = reader.readUint32();
    gid = reader.readUint32();
    fileSize = reader.readUint32();
    hash = GitHash.fromBytes(reader.read(20));

    var flags = reader.readUint16();
    assumeValid = (flags >> 12) & 0x8 > 0; //1000
    extended = ((flags >> 12) & 0x4) > 0; //0100
    intentToAdd = false;
    skipWorkTree = false;
    stage = GitFileStage((flags >> 12) & 0x3); // 0011

    if (extended && version == 2) {
      throw GitIndexException('Index version 2 must not have an extended flag');
    } else if (extended && version > 2) {
      var extendedFlags = reader.readUint16();
      const intentToAddMask = 1 << 13;
      const skipWorkTreeMask = 1 << 14;
      // TODO: support git add -N
      intentToAdd = (extendedFlags & intentToAddMask) > 0;
      // TODO: support sparse checkout
      skipWorkTree = (extendedFlags & skipWorkTreeMask) > 0;
    }
    switch (version) {
      case 2:
      case 3:
        const nameMask = 0xfff;
        var len = flags & nameMask;
        path = utf8.decode(reader.read(len));
        break;
      case 4:
        // In version 4 the path is truncated to reduce file size, relative to the previous path name.
        // 1) An integer N is calculated
        // 2) The current path is found by reading until we reach a nul byte.
        // 3) Remove N bytes from the path of the previous entry.
        // 4) Prepend it to the current path to obtain the full path
        var l = GitVLQCodec().decode(reader);
        var prefix = previousEntryPath == null ? '' : previousEntryPath.substring(0, previousEntryPath.length - l);
        var name = _readUntil(reader, 0x00);
        path = prefix + utf8.decode(name);
        break;
    }

    if (version == 4) return;
    // Read padding for version 2 and 3
    var entrySize = 62 + path.length;
    if (extended) entrySize += 2;
    var padLength = 8 - (entrySize % 8);
    reader.read(padLength);
  }

  Uint8List serialize(String previousEntryPath) {
    if (intentToAdd || skipWorkTree) {
      throw UnimplementedError('Unimplemented features intent-to-add and sparse checkout');
    }

    var writer = ByteDataWriter(endian: Endian.big);

    writer.writeUint32(cTime.seconds);
    writer.writeUint32(cTime.nanoSeconds);

    writer.writeUint32(mTime.seconds);
    writer.writeUint32(mTime.nanoSeconds);

    writer.writeUint32(device);
    writer.writeUint32(inode);

    writer.writeUint32(mode.val);

    writer.writeUint32(uid);
    writer.writeUint32(gid);
    writer.writeUint32(fileSize);

    writer.write(hash.bytes);

    const nameMask = 0xfff;
    var assumeValidBit = (assumeValid) ? 1 : 0;
    var extendedBit = (extended) ? 1 : 0;
    var pathLengthBits = (path.length < nameMask) ? path.length : nameMask;
    var flags = (assumeValidBit << 15) | (extendedBit << 14) | (stage.val << 12) | pathLengthBits;
    writer.writeUint16(flags);

    switch (version) {
      case 2:
      case 3:
        writer.write(ascii.encode(path));
        break;
      case 4:
        var prefix = '';
        var vlqLengthToRemove = GitVLQCodec().encode(0);

        if (previousEntryPath.isNotEmpty) {
          for (var i = 0; i < path.length; i++) {
            if (path[i] == previousEntryPath[i]) {
              prefix += path[i];
            } else {
              break;
            }
          }
        }
        var name = path.substring(prefix.length, path.length) + '\x00';
        vlqLengthToRemove = GitVLQCodec().encode(previousEntryPath.length - prefix.length);
        writer.write(vlqLengthToRemove);
        writer.write(ascii.encode(name));
        break;
    }

    if (version == 4) return writer.toBytes();
    // Add padding for version 2 and 3
    var entrySize = 62 + path.length;
    var padLength = 8 - entrySize % 8;
    writer.write(Uint8List(padLength));
    return writer.toBytes();
  }
}

class GitIndex {
  Map<String, GitIndexEntry> entries = {};

  final _signature = 'DIRC';
  int version;

  GitIndex({@required this.entries, @required this.version});

  GitIndex.fromBytes(Uint8List data) {
    var reader = ByteDataReader(endian: Endian.big);
    reader.add(data);
    var sig = ascii.decode(reader.read(4));
    if (sig != _signature || sig.length < 4) {
      throw GitIndexException('Invalid signature $sig');
    }
    version = reader.readUint32();
    if (version < 2 || version > 4) {
      throw GitIndexException('Version "$version" is unsupported; Only versions 2, 3 and 4 are supported');
    }
    var numEntries = reader.readUint32();
    var previousEntryPath = '';
    for (var i = 0; i < numEntries; i++) {
      var entry = GitIndexEntry.fromBytes(reader, previousEntryPath, version);
      previousEntryPath = entry.path;
      entries[entry.path] = entry;
    }
  }

  Uint8List serialize() {
    var writer = ByteDataWriter(endian: Endian.big);
    writer.write(ascii.encode(_signature));
    writer.writeUint32(version);
    writer.writeUint32(entries.length);
    var previousEntryPath = '';
    entries.forEach((path, entry) {
      var serialized = entry.serialize(previousEntryPath);
      previousEntryPath = entry.path;
      writer.write(serialized);
    });
    var hash = GitHash.compute(writer.toBytes());
    writer.write(hash.bytes);

    return writer.toBytes();
  }
}

class GitFileMode extends Equatable {
  final int val;

  const GitFileMode(this.val);

  static GitFileMode parse(String str) {
    var val = int.parse(str, radix: 8);
    return GitFileMode(val);
  }

  static final Empty = GitFileMode(0);
  static final Dir = GitFileMode(int.parse('40000', radix: 8));
  static final Regular = GitFileMode(int.parse('100644', radix: 8));
  static final Deprecated = GitFileMode(int.parse('100664', radix: 8));
  static final Executable = GitFileMode(int.parse('100755', radix: 8));
  static final Symlink = GitFileMode(int.parse('120000', radix: 8));
  static final Submodule = GitFileMode(int.parse('160000', radix: 8));

  @override
  List<Object> get props => [val];

  @override
  String toString() => val.toRadixString(8);
}

class GitFileStage extends Equatable {
  final int val;

  const GitFileStage(this.val);

  static const Merged = GitFileStage(1);
  static const AncestorMode = GitFileStage(1);
  static const OurMode = GitFileStage(2);
  static const TheirMode = GitFileStage(3);

  @override
  List<Object> get props => [val];

  @override
  bool get stringify => true;
}

class GitTimestamp {
  final DateTime dateTime;

  // This is necessary as DateTime only stores up to microSeconds
  final int seconds;
  final int nanoSeconds;

  GitTimestamp({@required this.dateTime, @required this.seconds, @required this.nanoSeconds});
}

Uint8List _readUntil(ByteDataReader reader, int r) {
  var l = <int>[];
  while (true) {
    var c = reader.readUint8();
    if (c == r) {
      return Uint8List.fromList(l);
    }
    l.add(c);
  }
}
