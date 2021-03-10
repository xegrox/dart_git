import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/utils.dart';

abstract class GitIndexExtension {
  String get signature;

  Uint8List serializeContent();

  Uint8List serialize() {
    var content = serializeContent();
    if (content.isEmpty) return Uint8List(0);
    var writer = ByteDataWriter();
    writer.write(ascii.encode(signature));
    writer.writeUint32(content.length);
    writer.write(content);
    return writer.toBytes();
  }
}

class GitIdxExtCachedTreeEntry {
  String path;
  int numEntries;
  int numSubtrees;
  GitHash hash;

  GitIdxExtCachedTreeEntry(
      {@required this.path, @required this.numEntries, @required this.numSubtrees, @required this.hash});

  GitIdxExtCachedTreeEntry.fromTree(this.path, GitTree tree) {
    numEntries = tree.entries.length;
    numSubtrees = 0;
    tree.entries.forEach((entry) {
      if (entry.mode == GitFileMode.Dir) numSubtrees++;
    });
    hash = tree.hash;
  }

  void invalidate() => numEntries = -1;

  bool isValid() => !numEntries.isNegative;
}

class GitIdxExtCachedTree extends GitIndexExtension {
  final Map<String, GitIdxExtCachedTreeEntry> _entries = SplayTreeMap();

  @override
  String get signature => 'TREE';

  GitIdxExtCachedTree();

  factory GitIdxExtCachedTree.fromBytes(Uint8List data) {
    var ext = GitIdxExtCachedTree();
    var reader = ByteDataReader();
    reader.add(data);
    while (reader.remainingLength != 0) {
      var path = ascii.decode(reader.readUntil(0x00));
      var numEntries = int.parse(ascii.decode(reader.readUntil(0x20)));
      var numSubtrees = int.parse(ascii.decode(reader.readUntil(0x0a)));
      GitHash hash;
      if (!numEntries.isNegative) hash = GitHash.fromBytes(reader.read(20));
      var entry = GitIdxExtCachedTreeEntry(path: path, numEntries: numEntries, numSubtrees: numSubtrees, hash: hash);
      ext.addEntry(entry);
    }
    return ext;
  }

  factory GitIdxExtCachedTree.fromTrees(Map<String, GitTree> treesMap) {
    var ext = GitIdxExtCachedTree();
    treesMap.forEach((path, tree) {
      var entry = GitIdxExtCachedTreeEntry.fromTree(path, tree);
      ext.addEntry(entry);
    });
    return ext;
  }

  void invalidateTree(String path) {
    var treePath = path;
    while (treePath != '.') {
      getEntry(treePath)?.invalidate();
      treePath = p.dirname(path);
    }
    getEntry('')?.invalidate(); // Invalidate root path
  }

  void addEntry(GitIdxExtCachedTreeEntry entry) => _entries[entry.path] = entry;

  GitIdxExtCachedTreeEntry getEntry(String path) => _entries[path];

  @override
  Uint8List serializeContent() {
    var data = <int>[];
    _entries.forEach((path, entry) {
      data.addAll(ascii.encode(entry.path));
      data.add(0x00);
      data.addAll(ascii.encode(entry.numEntries.toString()));
      data.add(0x20); // A space (ASCII 32)
      data.addAll(ascii.encode(entry.numSubtrees.toString()));
      data.add(0x0a); // A newline (ASCII 10)
      if (!entry.numEntries.isNegative) {
        data.addAll(entry.hash.bytes);
      }
    });
    return Uint8List.fromList(data);
  }
}
