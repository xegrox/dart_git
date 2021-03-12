import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';

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
    // We want to avoid continuously checking if a directory is empty whenever a child is removed,
    // as it might be costly, when there are too many child directories.
    // Hence, it is only checked after all children (in the list of entries to be removed) residing
    // in the same directory is removed, starting from the deepest entry.

    // Sort entries in top-down, depth-first order, while grouping sibling entries together
    entries.sort((a, b) {
      var depth1 = '/'.allMatches(a.path).length;
      var depth2 = '/'.allMatches(b.path).length;
      if (depth1 == depth2) {
        return b.path.compareTo(a.path);
      } else {
        return depth2 - depth1;
      }
    });

    // Once the iteration moves on to an entry that resides in a different directory, check if
    // the previous directory (containing the previous entry) is empty. If so, delete it.
    Directory previousParentDir;
    entries.forEach((entry) {
      var parentDir = Directory(p.join(dir.path, p.dirname(entry.path)));
      index.removeEntry(entry.path, entry.stage);
      if (!cached) {
        var file = File(p.join(dir.path, entry.path));
        if (file.existsSync()) file.deleteSync();
        if (previousParentDir != null && parentDir.path != previousParentDir.path) {
          if (previousParentDir.listSync().isEmpty) previousParentDir.deleteSync();
        }
      }
      previousParentDir = parentDir;
    });
    writeIndex(index);
  }
}
