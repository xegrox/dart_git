import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

enum GitFileStatus { newFile, deleted, modified }

class GitStatus {
  final DateTime _indexModified;
  final Map<String, GitIndexEntry> _indexEntries;
  final Map<String, GitTreeEntry> _treeEntries;
  final Map<String, FileSystemEntity> _workingFiles;

  GitStatus._(this._indexModified, this._indexEntries, this._treeEntries, this._workingFiles);

  Map<String, GitFileStatus> getStagedPaths() {
    // Paths in the index that differ from the current tree
    var modifiedPaths = <String>[];
    var newPaths = <String>[];
    var deletedPaths = _treeEntries.keys.toList();

    _indexEntries.forEach((path, entry) {
      deletedPaths.remove(path);
      if (_treeEntries.containsKey(path)) {
        var treeEntry = _treeEntries[path];
        if (treeEntry.hash != entry.hash) {
          // Modified file
          modifiedPaths.add(path);
        }
      } else {
        // New file
        newPaths.add(path);
      }
    });

    var stagedPaths = <String, GitFileStatus>{};
    modifiedPaths.forEach((e) => stagedPaths[e] = GitFileStatus.modified);
    newPaths.forEach((e) => stagedPaths[e] = GitFileStatus.newFile);
    deletedPaths.forEach((e) => stagedPaths[e] = GitFileStatus.deleted);
    return stagedPaths;
  }

  Map<String, GitFileStatus> getUnstagedPaths() {
    // Paths in working tree that differ from the index
    var unstagedPaths = <String, GitFileStatus>{};
    _indexEntries.forEach((path, entry) {
      if (_workingFiles.containsKey(path)) {
        var file = _workingFiles[path];
        var fileStat = file.statSync();
        var entryModified = entry.mTime.getDateTime();
        // Check if file is modified
        if (fileStat.size != entry.fileSize) {
          unstagedPaths[path] = GitFileStatus.modified;
        } else if (fileStat.modified.isAfter(entryModified) || fileStat.modified.compareTo(_indexModified) >= 0) {
          // Generate object hash and compare
          var content = (file is File) ? file.readAsBytesSync() : ascii.encode((file as Link).targetSync());
          var contentHash = GitBlob.fromBytes(content).hash;
          if (contentHash != entry.hash) unstagedPaths[path] = GitFileStatus.modified;
        }
      } else {
        // Deleted file
        unstagedPaths[path] = GitFileStatus.deleted;
      }
    });
    return unstagedPaths;
  }

  List<String> getUntrackedPaths() {
    // Paths that are not in the index or current tree
    var untrackedPaths = _workingFiles.keys.toList();
    var indexPaths = _indexEntries.keys;
    var treePaths = _treeEntries.keys;
    untrackedPaths.removeWhere((p) => indexPaths.contains(p) || treePaths.contains(p));
    return untrackedPaths;
  }
}

Map<String, GitTreeEntry> _getAllTreeEntries(GitRepo repo) {
  var treeEntries = <String, GitTreeEntry>{};
  // Recursively obtain all tree entries
  void l(String prefix, GitTree tree) {
    tree.entries.forEach((entry) {
      if (entry.mode == GitFileMode.dir) {
        l(prefix + entry.name + '/', repo.readObject(entry.hash) as GitTree);
      } else {
        treeEntries[prefix + entry.name] = entry;
      }
    });
  }

  var commitHash = repo.readHEAD().revParse().hash;
  if (commitHash != null) {
    var commit = repo.readObject(commitHash) as GitCommit;
    var tree = repo.readObject(commit.treeHash) as GitTree;
    l('', tree);
  }
  return treeEntries;
}

extension Status on GitRepo {
  GitStatus status() {
    var indexEntries = <String, GitIndexEntry>{
      for (var e in readIndex().getEntries())
        if (e.stage == GitFileStage(0)) e.path: e
    };
    var treeEntries = _getAllTreeEntries(this);
    var workingFiles = <String, FileSystemEntity>{};
    void l(Directory d) {
      d.listSync(followLinks: false).forEach((e) {
        if (e is Directory) {
          if (e.path != dotGitDir.path) l(e);
        } else {
          var relPath = p.relative(e.path, from: dir.path).replaceAll(p.separator, '/');
          workingFiles[relPath] = e;
        }
      });
    }

    l(dir);

    var idxStat = indexFile.statSync();
    return GitStatus._(idxStat.modified, indexEntries, treeEntries, workingFiles);
  }
}
