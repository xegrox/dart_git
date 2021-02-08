import 'dart:typed_data';
import 'object.dart';

class GitBlob extends GitObject {
  GitBlob.fromContent(Uint8List content) : super.fromContent(content);

  @override
  String get signature => 'blob';
}