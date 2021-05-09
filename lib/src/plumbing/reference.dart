import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';

const _refPrefix = 'refs/';
const _refHeadPrefix = _refPrefix + 'heads/';
const _refTagPrefix = _refPrefix + 'tags/';
const _refRemotePrefix = _refPrefix + 'remotes/';

enum GitReferenceType { hash, symbolic }

abstract class GitReference {
  final String refName;

  GitReference(this.refName) {
    // Check if refName is valid https://git-scm.com/docs/git-check-ref-format
    refName.split('/').forEach((name) {
      var exception = InvalidReferenceNameException('Invalid pathSpec name \'$name\' for ref');
      if (name.isEmpty || name == '@' || name[0] == '.' || name[name.length - 1] == '.') throw exception;
      var invalidChars = RegExp(r'@{|\.\.|[\x00-\x20\x7F\:\?\[\\\^\*\~\ \t]');
      if (name.contains(invalidChars)) throw exception;
      if (name.endsWith('.lock')) throw exception;
    });
  }

  GitReferenceHash revParse() {
    var r = this;
    while (r is GitReferenceSymbolic) {
      r = r.target;
    }
    return r as GitReferenceHash;
  }

  bool isHead() => refName.startsWith(_refHeadPrefix);

  bool isTag() => refName.startsWith(_refTagPrefix);

  bool isRemote() => refName.startsWith(_refRemotePrefix);

  Uint8List serialize();
}

class GitReferenceSymbolic extends GitReference with EquatableMixin {
  final GitReference target;

  GitReferenceSymbolic(String refName, this.target) : super(refName);

  @override
  Uint8List serialize() => ascii.encode('ref: ${target.refName}');

  @override
  List<Object?> get props => [refName, target];
}

class GitReferenceHash extends GitReference with EquatableMixin {
  final GitHash hash;

  GitReferenceHash(String refName, this.hash) : super(refName);

  @override
  Uint8List serialize() => ascii.encode(hash.toString());

  @override
  List<Object?> get props => [refName, hash];
}
