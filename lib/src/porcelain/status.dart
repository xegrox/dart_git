import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

enum GitFileStatus { newFile, deleted, modified }

extension Status on GitRepo {
  Map<String, GitFileStatus> getStagedPaths() {
    var indexEntries = readIndex().getEntries();

    var treeEntries = <String, GitTreeEntry>{};
    var headHashRef = readHEAD().obtainHashRef();
    if (headHashRef.hash != null) {
      var commit = readObject(headHashRef.hash) as GitCommit;
      var tree = readObject(commit.treeHash) as GitTree;
      // Recursively obtain all tree entries
      void l(String prefix, GitTree tree) {
        tree.entries.forEach((entry) {
          if (entry.mode == GitFileMode.dir) {
            l(prefix + entry.name + '/', readObject(entry.hash) as GitTree);
          } else {
            treeEntries[prefix + entry.name] = entry;
          }
        });
      }

      l('', tree);
    }

    var modifiedPaths = <String>[];
    var newPaths = <String>[];
    var deletedPaths = treeEntries.values.map((e) => e.name).toList();

    indexEntries.forEach((entry) {
      deletedPaths.remove(entry.path);
      if (treeEntries.containsKey(entry.path)) {
        var treeEntry = treeEntries[entry.path];
        if (treeEntry.hash != entry.hash) {
          // Modified file
          modifiedPaths.add(entry.path);
        }
      } else {
        // New file
        newPaths.add(entry.path);
      }
    });

    var stagedPaths = <String, GitFileStatus>{};
    modifiedPaths.forEach((e) => stagedPaths[e] = GitFileStatus.modified);
    newPaths.forEach((e) => stagedPaths[e] = GitFileStatus.newFile);
    deletedPaths.forEach((e) => stagedPaths[e] = GitFileStatus.deleted);
    return stagedPaths;
  }
}
