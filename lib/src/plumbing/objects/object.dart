import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_git/src/git_hash.dart';

abstract class GitObject {
  final Uint8List content;

  GitObject.fromContent(this.content);

  String get signature;

  Uint8List serialize() {
    List<int> serializedData = [];
    var contentLength = content.lengthInBytes;
    serializedData.addAll(utf8.encode('$signature $contentLength'));
    serializedData.add(0x00);
    serializedData.addAll(content);
    return Uint8List.fromList(serializedData);
  }

  GitHash get hash => GitHash.compute(serialize());

}