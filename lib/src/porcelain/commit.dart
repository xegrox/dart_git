import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
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
    if (rootTree == null) {
      throw NothingToCommitException();
    } else if (headCommitHash != null) {
      var parentCommit = readObject(headCommitHash) as GitCommit;
      if (parentCommit.treeHash == rootTree.hash) throw NothingToCommitException();
      parentHashes.add(headCommitHash);
    }

    // Write objects
    var config = readConfig();
    var commit = GitCommit.fromTree(rootTree, message, config, parentHashes);
    writeObject(commit);

    // Write head
    headHashRef = GitReferenceHash(headHashRef.pathSpec, commit.hash);
    writeReference(headHashRef);
    return commit.hash;
  }
}
