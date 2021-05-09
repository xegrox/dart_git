import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/reference.dart';

extension Commit on GitRepo {
  GitHash commit(String message) {
    validate();

    var parentHashes = <GitHash>[];
    var index = readIndex();
    var rootTree = index.computeTrees((tree) {
      writeObject(tree);
    });

    late String refName;
    try {
      var headHashRef = readHEAD().revParse();
      refName = headHashRef.refName;
      var parentCommit = readObject<GitCommit>(headHashRef.hash);
      if (parentCommit.treeHash == rootTree.hash) throw NothingToCommitException();
      parentHashes.add(headHashRef.hash);
    } on PathSpecNoMatchException catch (e) {
      // First commit on empty branch
      if (rootTree.entries.isEmpty) throw NothingToCommitException();
      refName = e.pathSpec;
    }

    // Write objects
    var config = readConfig();
    var username = config.getValue<GitConfigValueString>('user', 'name');
    var email = config.getValue<GitConfigValueString>('user', 'email');
    if (username == null || email == null) throw MissingCredentialsException();
    var time = DateTime.now();
    var user = GitUserTimestamp(username.value, email.value, time, time.timeZoneOffset);
    var commit = GitCommit(rootTree.hash, user, user, message, parentHashes);
    writeObject(commit);

    // Write head
    writeReference(GitReferenceHash(refName, commit.hash));
    return commit.hash;
  }
}
