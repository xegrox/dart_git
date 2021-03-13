import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/plumbing/objects/object.dart';

class GitTag extends GitObject with EquatableMixin {
  @override
  String get signature => 'tag';

  String name;
  GitObject object;

  GitTag.fromBytes(Uint8List data) {}

  @override
  Uint8List serializeContent() {}

  @override
  List<Object> get props => [];
}
