import 'dart:typed_data';
import 'object.dart';

class GitBlob extends GitObject {
  GitBlob(Uint8List data) : super(GitObjectType.blob, data);

  static GitBlob fromBytes(Uint8List data) => GitBlob(data);

}