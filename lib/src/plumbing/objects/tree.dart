import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';

class GitTreeEntry extends Equatable {
  GitTreeEntry({@required this.mode, @required this.path, @required this.hash});

  final String path;
  final GitFileMode mode;
  final GitHash hash;

  @override
  List<Object> get props => [path, mode, hash];
}

class GitTree extends GitObject with EquatableMixin {
  List<GitTreeEntry> entries;

  @override
  String get signature => 'tree';

  GitTree.fromBytes(Uint8List data) {
    var content = super.getContent(data);
    entries = [];
    var reader = ByteDataReader();
    reader.add(content);
    try {
      while (reader.remainingLength != 0) {
        var modeInt = ascii.decode(_readUntil(reader, 32));
        var mode = GitFileMode.parse(modeInt);
        var path = ascii.decode(_readUntil(reader, 0x00));
        var hash = GitHash.fromBytes(reader.read(20));
        var entry = GitTreeEntry(mode: mode, path: path, hash: hash);
        entries.add(entry);
      }
    } catch (e) {
      throw GitException('invalid tree object format');
    }
  }

  GitTree.fromIndexEntries(List<GitIndexEntry> indexEntries) {
    entries = [];
    indexEntries.forEach((e) {
      var entry = GitTreeEntry(mode: e.mode, path: e.path, hash: e.hash);
      entries.add(entry);
    });
  }

  @override
  Uint8List serializeContent() {
    var data = <int>[];
    entries.forEach((entry) {
      var mode = entry.mode.toString();
      var hash = entry.hash.bytes;
      var fmt = '$mode ${entry.path}\x00';
      data.addAll(ascii.encode(fmt));
      data.addAll(hash);
    });
    return Uint8List.fromList(data);
  }

  @override
  List<Object> get props => [entries];
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
