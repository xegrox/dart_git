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
    var indexEntryList = index.entries.values.toList();
    var tree = GitTree.fromIndexEntries(indexEntryList);

    // Check if there is anything to commit
    GitHash parentHash;
    if (refTarget.existsSync()) {
      parentHash = head.readHash();
      var parentCommit = readObject(GitObjectType.commit, parentHash) as GitCommit;
      var parentTree = readObject(GitObjectType.tree, parentCommit.treeHash) as GitTree;
      if (parentTree == tree) throw NothingToCommitException();
    } else if (indexEntryList.isEmpty) throw NothingToCommitException();

    var config = readConfig();
    var commit = GitCommit.fromTree(tree, message, config, parentHash: parentHash);

    writeObject(tree);
    writeObject(commit);
    readObject(GitObjectType.commit, commit.hash);
    refTarget.createSync();
    refTarget.writeAsStringSync(commit.hash.toString());
  }
}
