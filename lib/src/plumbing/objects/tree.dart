import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/utils.dart';

class GitTreeEntry extends Equatable {
  GitTreeEntry({required this.mode, required this.name, required this.hash});

  final String name;
  final GitFileMode mode;
  final GitHash hash;

  Uint8List serialize() {
    var data = <int>[];
    var fmt = '$mode $name';
    data.addAll(ascii.encode(fmt));
    data.add(0x00);
    data.addAll(hash.bytes);
    return Uint8List.fromList(data);
  }

  @override
  List<Object> get props => [name, mode, hash];
}

class GitTree extends GitObject with EquatableMixin {
  final List<GitTreeEntry> entries;

  @override
  String get signature => GitObjectSignature.tree;

  GitTree(this.entries);

  factory GitTree.fromBytes(Uint8List data) {
    var reader = ByteDataReader();
    reader.add(data);
    var entries = <GitTreeEntry>[];
    try {
      while (reader.remainingLength != 0) {
        var modeInt = ascii.decode(reader.readUntil(32));
        var mode = GitFileMode.parse(modeInt);
        var path = ascii.decode(reader.readUntil(0x00));
        var hash = GitHash.fromBytes(reader.read(20));
        var entry = GitTreeEntry(mode: mode, name: path, hash: hash);
        entries.add(entry);
      }
    } catch (e) {
      throw CorruptObjectException('Invalid tree format');
    }
    return GitTree(entries);
  }

  @override
  Uint8List serializeContent() {
    var data = <int>[];
    entries.forEach((entry) {
      data.addAll(entry.serialize());
    });
    return Uint8List.fromList(data);
  }

  @override
  List<Object> get props => [entries];
}
