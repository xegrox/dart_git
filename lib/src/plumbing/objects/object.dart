import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_git/src/git_hash.dart';

enum GitObjectType {
 blob,
 commit
}

extension on GitObjectType {
  String get name {
    switch (this) {
      case GitObjectType.blob:
        return 'blob';
      case GitObjectType.commit:
        return 'commit';
    }
  }
}

abstract class GitObject {
  final GitObjectType type;
  final Uint8List data;

  GitObject(this.type, this.data);

  Uint8List serialize() {
    var content = utf8.decode(data);
    var contentLength = data.lengthInBytes;
    var serializedData = '${type.name} ${contentLength}\x00$content';
    return utf8.encode(serializedData);
  }

  GitHash get hash => GitHash.compute(serialize());

}