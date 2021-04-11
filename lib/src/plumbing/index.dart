import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_vlq_codec.dart';
import 'package:dart_git/src/plumbing/index_extensions.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/utils.dart';

class GitIndexEntry {
  final int version;
  final GitIndexTimestamp cTime;
  final GitIndexTimestamp mTime;
  final int device;
  final int inode;
  final GitFileMode mode;
  final int uid;
  final int gid;
  final int fileSize;
  final GitHash hash;
  final GitFileStage stage;
  final String path;
  final bool assumeValid;
  final bool extended;
  final bool skipWorkTree;
  final bool intentToAdd;

  GitIndexEntry(
      {required this.version,
      required this.cTime,
      required this.mTime,
      required this.device,
      required this.inode,
      required this.mode,
      required this.uid,
      required this.gid,
      required this.fileSize,
      required this.hash,
      required this.stage,
      required this.path,
      this.assumeValid = false,
      this.extended = false,
      this.skipWorkTree = false,
      this.intentToAdd = false});

  static final _vlqCodec = GitVLQCodec(offset: true);

  factory GitIndexEntry.fromBytes(ByteDataReader reader, String? previousEntryPath, int indexVersion) {
    var version = indexVersion;

    var cTimeSeconds = reader.readUint32();
    var cTimeNanoSeconds = reader.readUint32();
    var cTime = GitIndexTimestamp(cTimeSeconds, cTimeNanoSeconds);

    var mTimeSeconds = reader.readUint32();
    var mTimeNanoSeconds = reader.readUint32();
    var mTime = GitIndexTimestamp(mTimeSeconds, mTimeNanoSeconds);

    var device = reader.readUint32();
    var inode = reader.readUint32();
    var mode = GitFileMode(reader.readUint32());
    var uid = reader.readUint32();
    var gid = reader.readUint32();
    var fileSize = reader.readUint32();
    var hash = GitHash.fromBytes(reader.read(20));

    var flags = reader.readUint16();
    var assumeValid = (flags >> 12) & 0x8 > 0; //1000
    var extended = ((flags >> 12) & 0x4) > 0; //0100
    var intentToAdd = false;
    var skipWorkTree = false;
    var stage = GitFileStage((flags >> 12) & 0x3); // 0011

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

    late String path;
    switch (version) {
      case 2:
      case 3:
        const nameMask = 0xfff;
        var len = flags & nameMask;
        path = (len == 0xfff) // If path len exceeds 0xfff then read until nul
            ? utf8.decode(reader.readUntil(0x00))
            : utf8.decode(reader.read(len));
        break;
      case 4:
        // In version 4 the path is truncated to reduce file size, relative to the previous path name.
        // 1) An integer N is calculated
        // 2) The current path is found by reading until we reach a nul byte.
        // 3) Remove N bytes from the path of the previous entry.
        // 4) Prepend it to the current path to obtain the full path
        var l = _vlqCodec.decode(reader);
        var prefix = previousEntryPath == null ? '' : previousEntryPath.substring(0, previousEntryPath.length - l);
        var name = reader.readUntil(0x00);
        path = prefix + utf8.decode(name);
        break;
    }

    if (version != 4) {
      // Read padding for version 2 and 3
      var entrySize = 62 + path.length;
      if (extended) entrySize += 2;
      var padLength = 8 - (entrySize % 8);
      reader.read(padLength);
    }

    return GitIndexEntry(
        version: version,
        cTime: cTime,
        mTime: mTime,
        device: device,
        inode: inode,
        mode: mode,
        uid: uid,
        gid: gid,
        fileSize: fileSize,
        hash: hash,
        stage: stage,
        path: path,
        assumeValid: assumeValid,
        extended: extended,
        skipWorkTree: skipWorkTree,
        intentToAdd: intentToAdd);
  }

  Uint8List serialize(String previousEntryPath) {
    if (intentToAdd || skipWorkTree) {
      // TODO: implement intentToAdd and skipWorkTree
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
        var vlqLengthToRemove = _vlqCodec.encode(previousEntryPath.length - prefix.length);
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

class _GitIndexEntryKey {
  final String path;
  final GitFileStage stage;

  _GitIndexEntryKey(this.path, this.stage);

  _GitIndexEntryKey.fromEntry(GitIndexEntry entry)
      : path = entry.path,
        stage = entry.stage;
}

class GitIndex {
  final Map<_GitIndexEntryKey, GitIndexEntry> _entries = SplayTreeMap((a, b) {
    // Index entries are sorted in ascending order on the name field,
    // interpreted as a string of unsigned bytes (i.e. memcmp() order, no
    // localization, no special casing of directory separator '/'). Entries
    // with the same name are sorted by their stage field.
    var cmpName = a.path.compareTo(b.path);
    if (cmpName == 0) {
      return a.stage.val.compareTo(b.stage.val);
    } else {
      return cmpName;
    }
  });

  static final _signature = 'DIRC';
  int version;

  var extCachedTree = GitIdxExtCachedTree();

  GitIndex(List<GitIndexEntry> entries, {this.version = 2}) {
    entries.forEach((entry) {
      var key = _GitIndexEntryKey.fromEntry(entry);
      _entries[key] = entry;
    });
  }

  factory GitIndex.fromBytes(Uint8List data) {
    var entries = <GitIndexEntry>[];
    var reader = ByteDataReader(endian: Endian.big);
    reader.add(data);

    // Header
    var sig = ascii.decode(reader.read(4));
    if (sig != _signature) {
      throw GitIndexException('Invalid signature $sig');
    }
    var version = reader.readUint32();
    if (version < 2 || version > 4) {
      throw GitIndexException('Version "$version" is unsupported; Only versions 2, 3 and 4 are supported');
    }

    // Entries
    var numEntries = reader.readUint32();
    var previousEntryPath = '';
    for (var i = 0; i < numEntries; i++) {
      var entry = GitIndexEntry.fromBytes(reader, previousEntryPath, version);
      previousEntryPath = entry.path;
      entries.add(entry);
    }

    var index = GitIndex(entries, version: version);

    // Extensions
    while (reader.remainingLength != 20) {
      var signature = ascii.decode(reader.read(4));
      var len = reader.readUint32();
      var data = reader.read(len);
      var isOptional = signature.substring(0, 1).toUpperCase() == signature.substring(0, 1);

      switch (signature) {
        case 'TREE':
          index.extCachedTree = GitIdxExtCachedTree.fromBytes(data);
          break;
        default:
          if (isOptional) {
            reader.read(len);
          } else {
            throw GitIndexException('Unknown extension \'$signature\'');
          }
      }
    }

    // Hash checksum over contents
    var genHash = GitHash.compute(data.sublist(0, data.length - 20));
    var hash = GitHash.fromBytes(reader.read(20));
    if (genHash != hash) throw GitIndexException('Invalid file hash $genHash');
    return index;
  }

  List<GitIndexEntry> getEntries() => _entries.values.toList();

  void setEntry(GitIndexEntry entry) {
    if (p.isWithin(entry.path, '.git')) return;
    var key = _GitIndexEntryKey.fromEntry(entry);
    var exists = _entries.containsKey(key);
    _entries[key] = entry;
    if (exists) return;
    // Invalidate cached tree entry
    var entryTreePath = p.dirname(entry.path);
    extCachedTree.invalidateTree(entryTreePath);
  }

  bool removeEntry(String path, GitFileStage stage) {
    var key = _GitIndexEntryKey(path, stage);
    if (_entries.remove(key) == null) return false;
    // Invalidate cached tree entry
    var entryTreePath = p.dirname(path);
    extCachedTree.invalidateTree(entryTreePath);
    return true;
  }

  /// Returns the root tree object
  ///
  /// onNewTree is called when the tree or any of its parents are not found in the cache tree extension
  /// The tree itself might not have been modified.
  GitTree computeTrees([Function(GitTree tree)? onNewTree]) {
    // Keep track of the paths of cached entries
    var cachedTreePaths = <String>[];
    // Sort trees in top-down, depth-first order, while grouping sibling entries together
    var newTreesMap = SplayTreeMap<String, GitTree>((a, b) {
      var depth1 = '/'.allMatches(a).length;
      var depth2 = '/'.allMatches(b).length;
      if (depth1 == depth2) {
        return b.compareTo(a);
      } else {
        return depth2 - depth1;
      }
    });

    for (var i = 0; i < _entries.length; i++) {
      var key = _entries.keys.elementAt(i);
      var entry = _entries.values.elementAt(i);
      var name = p.basename(key.path);
      var dirPath = p.dirname(key.path);
      if (dirPath == '.') dirPath = '';

      // Skip generation of cached trees
      if ((extCachedTree.getEntry(dirPath)?.isValid() ?? false)) {
        cachedTreePaths.add(dirPath);
        // We have to generate at least the root tree
        if (dirPath.isNotEmpty) {
          continue;
        }
      }

      // Generate trees that have not been cached
      var treeEntry = GitTreeEntry(mode: entry.mode, name: name, hash: entry.hash);
      newTreesMap.putIfAbsent(dirPath, () => GitTree([]));
      newTreesMap[dirPath]!.entries.add(treeEntry);
    }

    // Iterates from deepest directory
    newTreesMap.forEach((dir, tree) {
      // Add the tree as an entry in its parent tree
      if (dir.isNotEmpty) {
        var treeEntry = GitTreeEntry(mode: GitFileMode.dir, name: p.basename(dir), hash: tree.hash);
        var parentPath = p.dirname(dir);
        if (parentPath == '.') parentPath = '';
        newTreesMap[parentPath]!.entries.add(treeEntry);
      }

      // Cache these trees
      var cachedEntry = GitIdxExtCachedTreeEntry.fromTree(dir, tree);
      extCachedTree.addEntry(cachedEntry);
      if (onNewTree != null && !cachedTreePaths.any((path) => dir.startsWith(path))) {
        onNewTree(tree);
      }
    });
    return newTreesMap[''] ?? GitTree([]);
  }

  Uint8List serialize() {
    var writer = ByteDataWriter(endian: Endian.big);
    writer.write(ascii.encode(_signature));
    writer.writeUint32(version);
    writer.writeUint32(_entries.length);

    var previousEntryPath = '';
    _entries.forEach((path, entry) {
      var serialized = entry.serialize(previousEntryPath);
      previousEntryPath = entry.path;
      writer.write(serialized);
    });

    // Write extensions
    writer.write(extCachedTree.serialize());

    var hash = GitHash.compute(writer.toBytes());
    writer.write(hash.bytes);

    return writer.toBytes();
  }
}

class GitFileMode extends Equatable {
  final int val;

  const GitFileMode(this.val);

  factory GitFileMode.parse(String str) {
    var val = int.parse(str, radix: 8);
    return GitFileMode(val);
  }

  static final dir = GitFileMode(int.parse('40000', radix: 8));
  static final regular = GitFileMode(int.parse('100644', radix: 8));
  static final deprecated = GitFileMode(int.parse('100664', radix: 8));
  static final executable = GitFileMode(int.parse('100755', radix: 8));
  static final symlink = GitFileMode(int.parse('120000', radix: 8));
  static final submodule = GitFileMode(int.parse('160000', radix: 8));

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

class GitIndexTimestamp {
  // This is necessary as DateTime only stores up to microSeconds
  final int seconds;
  final int nanoSeconds;

  DateTime getDateTime() =>
      DateTime.fromMillisecondsSinceEpoch(0).add(Duration(seconds: seconds, microseconds: nanoSeconds ~/ 1000));

  GitIndexTimestamp(this.seconds, this.nanoSeconds);
}
