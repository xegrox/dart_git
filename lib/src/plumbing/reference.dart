import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/src/git_hash.dart';

const _refPrefix = 'refs/';
const _refHeadPrefix = _refPrefix + 'heads/';
const _refTagPrefix = _refPrefix + 'tags/';
const _refRemotePrefix = _refPrefix + 'remotes/';

enum GitReferenceType { hash, symbolic }

abstract class GitReference {
  // Path of ref relative to .git (e.g. HEAD, refs/heads/master)
  final String pathSpec;

  GitReference(this.pathSpec);

  bool isHead() => pathSpec.startsWith(_refHeadPrefix);

  bool isTag() => pathSpec.startsWith(_refTagPrefix);

  bool isRemote() => pathSpec.startsWith(_refRemotePrefix);

  Uint8List serialize();
}

class GitReferenceSymbolic extends GitReference {
  GitReference target;

  GitReferenceSymbolic(String pathSpec, this.target) : super(pathSpec);

  @override
  Uint8List serialize() => ascii.encode('ref: ${target.pathSpec}');
}

class GitReferenceHash extends GitReference {
  GitHash hash;

  GitReferenceHash(String pathSpec, this.hash) : super(pathSpec);

  @override
  Uint8List serialize() => ascii.encode(hash.toString());
}
