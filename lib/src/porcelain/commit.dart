import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

extension Commit on GitRepo {
  commit(String message) {
    // FIXME: check for changes in working tree
    this.validate();
    var index = this.readIndex();
    var config = this.readConfig();
    var head = this.readHEAD();
    var tree = GitTree.fromEntries(index.entries);
    var commit = GitCommit.fromTree(tree, message, config);
    this.writeObject(tree);
    this.writeObject(commit);

    var refTarget = head.resolveTargetFile();
    refTarget.createSync();
    refTarget.writeAsStringSync(commit.hash.toString());
  }
}