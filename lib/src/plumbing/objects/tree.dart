import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';

class GitTree extends GitObject {
  GitTree.fromContent(Uint8List data) : super.fromContent(data);

  static GitTree fromEntries(Map<String, GitIndexEntry> entries) {
    List<int> data = [];
    entries.forEach((path, entry) {
      var mode = entry.mode.toString();
      var hash = entry.hash.bytes;
      var fmt = '$mode $path\x00';
      data.addAll(ascii.encode(fmt));
      data.addAll(hash);
    });
    return GitTree.fromContent(Uint8List.fromList(data));
  }

  @override
  String get signature => 'tree';
}