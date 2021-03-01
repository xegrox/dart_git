import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/src/git_hash.dart';

abstract class GitObjectSignature {
  static const commit = 'commit';
  static const tree = 'tree';
  static const blob = 'blob';
}

abstract class GitObject {
  GitObject();

  String get signature;

  Uint8List serializeContent();

  Uint8List serialize() {
    var serializedData = <int>[];
    var content = serializeContent();
    serializedData.addAll(ascii.encode('$signature ${content.length}'));
    serializedData.add(0x00);
    serializedData.addAll(content);
    return Uint8List.fromList(serializedData);
  }

  GitHash get hash => GitHash.compute(serialize());
}
