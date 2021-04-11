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

    var index = readIndex();
    var headHashRef = readHEAD().revParse();
    var headCommitHash = headHashRef.hash;
    var rootTree = index.computeTrees((tree) {
      writeObject(tree);
    });
    var parentHashes = <GitHash>[];

    // Check if there is anything to commit
    if (headCommitHash != null) {
      var parentCommit = readObject(headCommitHash) as GitCommit;
      if (parentCommit.treeHash == rootTree.hash) throw NothingToCommitException();
      parentHashes.add(headCommitHash);
    } else if (rootTree.entries.isEmpty) {
      throw NothingToCommitException();
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
    headHashRef = GitReferenceHash(headHashRef.pathSpec, commit.hash);
    writeReference(headHashRef);
    return commit.hash;
  }
}
