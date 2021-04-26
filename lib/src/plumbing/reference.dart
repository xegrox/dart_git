import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';

const _refPrefix = 'refs/';
const _refHeadPrefix = _refPrefix + 'heads/';
const _refTagPrefix = _refPrefix + 'tags/';
const _refRemotePrefix = _refPrefix + 'remotes/';

enum GitReferenceType { hash, symbolic }

abstract class GitReference {
  final String pathSpec;

  GitReference(this.pathSpec) {
    pathSpec.split('/').forEach((name) {
      var exception = GitException('Invalid pathSpec name \'$name\' for ref');
      if (name.isEmpty || name[0] == '.') throw exception;
      var invalidChars = RegExp(r'@{|[:\?\[\\\^\*\~\ \t]');
      if (name.contains(invalidChars)) throw exception;
      if (name.endsWith('/') || name.endsWith('.lock')) throw exception;
    });
  }

  GitReferenceHash revParse() {
    var r = this;
    while (r is GitReferenceSymbolic) {
      r = r.target;
    }
    return r as GitReferenceHash;
  }

  bool isHead() => pathSpec.startsWith(_refHeadPrefix);

  bool isTag() => pathSpec.startsWith(_refTagPrefix);

  bool isRemote() => pathSpec.startsWith(_refRemotePrefix);

  Uint8List serialize();
}

class GitReferenceSymbolic extends GitReference {
  final GitReference target;

  GitReferenceSymbolic(String pathSpec, this.target) : super(pathSpec);

  @override
  Uint8List serialize() => ascii.encode('ref: ${target.pathSpec}');
}

class GitReferenceHash extends GitReference {
  final GitHash? hash;

  GitReferenceHash(String pathSpec, this.hash) : super(pathSpec);

  @override
  Uint8List serialize() => ascii.encode(hash.toString());
}
