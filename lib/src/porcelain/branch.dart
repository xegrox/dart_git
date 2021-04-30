import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart' show GitRepo, RepoTree;
import 'package:dart_git/src/plumbing/reference.dart';

extension Branch on GitRepo {
  GitReference createBranch(String name, GitHash revision) {
    var file = File(p.join(refHeadsFolder.path, name));
    late GitReferenceHash ref;
    try {
      ref = GitReferenceHash(p.join('refs/heads', name), revision);
    } on InvalidReferenceNameException {
      throw InvalidBranchNameException(name);
    }

    file.createSync(recursive: true);
    file.writeAsBytesSync(ref.serialize());
    return ref;
  }

  void deleteBranch(String name) {
    late GitReferenceHash ref;
    try {
      ref = readReference('refs/heads/$name').revParse();
    } on GitException catch (_) {
      throw BranchNotFoundException(name);
    }
    if (readHEAD().revParse() == ref) throw DeleteCheckedOutBranchException(name);
    var file = File(p.join(refHeadsFolder.path, name));
    file.deleteSync();
    // Delete parent if empty
    var parent = file.parent;
    while (parent.path != refHeadsFolder.path && parent.listSync().isEmpty) {
      parent.deleteSync();
      parent = parent.parent;
    }
  }
}
