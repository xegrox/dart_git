import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/plumbing/objects/object.dart';

class GitBlob extends GitObject with EquatableMixin {
  Uint8List content;

  @override
  String get signature => 'blob';

  GitBlob.fromBytes(Uint8List data) {
    content = super.getContent(data);
  }

  GitBlob.fromContent(this.content);

  @override
  Uint8List serializeContent() => content;

  @override
  List<Object> get props => [content];
}
