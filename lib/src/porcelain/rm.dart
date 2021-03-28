import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_repo.dart';

extension Remove on GitRepo {
  void rm(String pathSpec, {bool cached = false}) {
    validate();
    var fullPath = p.normalize(p.join(dir.path, pathSpec));
    if (!fullPath.startsWith(dir.path)) {
      throw PathSpecOutsideRepoException(dir.path, pathSpec);
    }

    var index = readIndex();
    var exception = PathSpecNoMatchException(pathSpec);

    // Entries to be removed
    var entries = index.getEntries().where((entry) {
      if (fullPath == dir.path) return true;
      var cmpPathSpec = (pathSpec.endsWith('/')) ? pathSpec : pathSpec + '/';
      return (entry.path + '/').startsWith(cmpPathSpec);
    }).toList();
    if (entries.isEmpty) throw exception;

    // Directories that are left empty after the file deletions should be removed as well
    // Sort directories in top-down, depth-first order
    var parentDirs = SplayTreeSet<Directory>((a, b) {
      var depth1 = '/'.allMatches(a.path).length;
      var depth2 = '/'.allMatches(b.path).length;
      if (depth1 == depth2) {
        return b.path.compareTo(a.path);
      } else {
        return depth2 - depth1;
      }
    });

    entries.forEach((entry) {
      parentDirs.add(Directory(p.join(dir.path, p.dirname(entry.path))));
      index.removeEntry(entry.path, entry.stage);
      if (!cached) {
        var file = File(p.join(dir.path, entry.path));
        if (file.existsSync()) file.deleteSync();
      }
    });

    if (!cached) {
      var cachedNonEmptyPaths = <String>[];
      parentDirs.forEach((dir) {
        if (cachedNonEmptyPaths.any((p) => p.startsWith(dir.path))) return;
        if (dir.listSync().isEmpty) {
          dir.deleteSync();
        } else {
          cachedNonEmptyPaths.add(dir.path);
        }
      });
    }

    writeIndex(index);
  }
}
