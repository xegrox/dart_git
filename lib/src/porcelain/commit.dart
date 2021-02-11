import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

extension Commit on GitRepo {
  commit(String message) {
    this.validate();

    var index = this.readIndex();
    var config = this.readConfig();
    var head = this.readHEAD();
    var refTarget = head.resolveTargetFile();
    var indexEntryList = index.entries.values.toList();
    var tree = GitTree.fromIndexEntries(indexEntryList);

    // Check if there is anything to commit
    GitHash parentHash;
    if (refTarget.existsSync()) {
      parentHash = head.readHash();
      var parentCommit = this.readObject(GitObjectType.commit, parentHash) as GitCommit;
      var parentTree = this.readObject(GitObjectType.tree, parentCommit.treeHash) as GitTree;
      if (parentTree == tree) throw NothingToCommitException();
    } else if (indexEntryList.isEmpty) throw NothingToCommitException();

    var commit = GitCommit.fromTree(tree, message, config, parentHash: parentHash);

    this.writeObject(tree);
    this.writeObject(commit);
    this.readObject(GitObjectType.commit, commit.hash);
    refTarget.createSync();
    refTarget.writeAsStringSync(commit.hash.toString());
  }
}