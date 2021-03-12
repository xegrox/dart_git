import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';

extension Commit on GitRepo {
  void commit(String message) {
    validate();

    var index = readIndex();
    var head = readHEAD();
    var headHash = head.readHash();
    var rootTree = index.computeTrees((tree) {
      writeObject(tree);
    });

    // Check if there is anything to commit
    if (rootTree == null) {
      throw NothingToCommitException();
    } else if (headHash != null) {
      var parentCommit = readObject(headHash) as GitCommit;
      if (parentCommit.treeHash == rootTree.hash) throw NothingToCommitException();
    }

    var config = readConfig();
    var commit = GitCommit.fromTree(rootTree, message, config, headHash);
    writeObject(commit);
    head.resolveTargetFile().createSync();
    head.resolveTargetFile().writeAsStringSync(commit.hash.toString());
  }
}
