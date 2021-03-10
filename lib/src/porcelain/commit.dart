import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

extension Commit on GitRepo {
  void commit(String message) {
    validate();

    var index = readIndex();
    var head = readHEAD();
    var refTarget = head.resolveTargetFile();
    var rootTree = index.computeTrees((tree) {
      writeObject(tree);
    });

    // Check if there is anything to commit
    GitHash parentHash;
    if (rootTree == null) {
      throw NothingToCommitException();
    } else if (refTarget.existsSync()) {
      parentHash = head.readHash();
      var parentCommit = readObject(parentHash) as GitCommit;
      var parentTree = readObject(parentCommit.treeHash) as GitTree;
      if (parentTree == rootTree) throw NothingToCommitException();
    }

    var config = readConfig();
    var commit = GitCommit.fromTree(rootTree, message, config, parentHash);
    writeObject(commit);
    refTarget.createSync();
    refTarget.writeAsStringSync(commit.hash.toString());
  }
}
