import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/reference.dart';

extension Commit on GitRepo {
  void commit(String message) {
    validate();

    var index = readIndex();
    var refHash = readHEAD();
    while (refHash is GitReferenceSymbolic) {
      refHash = (refHash as GitReferenceSymbolic).target;
    }
    var parentHash = (refHash as GitReferenceHash).hash;
    var rootTree = index.computeTrees((tree) {
      writeObject(tree);
    });

    // Check if there is anything to commit
    if (rootTree == null) {
      throw NothingToCommitException();
    } else if (parentHash != null) {
      var parentCommit = readObject(parentHash) as GitCommit;
      if (parentCommit.treeHash == rootTree.hash) throw NothingToCommitException();
    }

    // Write objects
    var config = readConfig();
    var commit = GitCommit.fromTree(rootTree, message, config, parentHash);
    writeObject(commit);

    // Write head
    (refHash as GitReferenceHash).hash = commit.hash;
    writeReference(refHash, true);
  }
}
