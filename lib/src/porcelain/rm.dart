import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';

extension Remove on GitRepo {
  void rm(FileSystemEntity entity, {bool cached = false}) {
    validate();
    if (p.isWithin(getGitDir().path, entity.path) || entity.path == getGitDir().path) return;
    if (!p.isWithin(dir.path, entity.path) && entity.path != dir.path) {
      throw PathSpecOutsideRepoException(dir.path, entity.path);
    }

    var index = readIndex();
    var pathSpec = p.relative(entity.path, from: dir.path);
    var exception = PathSpecNoMatchException(pathSpec);

    if (entity is Link || entity is File) {
      var path = p.relative(entity.path, from: dir.path);
      if (!index.removeEntry(path)) throw exception;
    } else {
      var dirToRemove = entity as Directory;
      var success = false; // True if anything is removed successfully
      bool removeRecursively(Directory d) {
        var isEmpty = true;
        d.listSync().forEach((entity) {
          if (entity is File || entity is Link) {
            var path = p.relative(entity.path, from: d.path);
            if (index.removeEntry(path)) {
              success = true;
              if (!cached) entity.deleteSync();
            } else {
              isEmpty = false;
            }
          } else {
            // Directory
            if (!removeRecursively(entity as Directory)) isEmpty = false;
          }
        });
        if (isEmpty) d.deleteSync();
        return isEmpty;
      }

      if (removeRecursively(dirToRemove)) dirToRemove.deleteSync();
      if (!success) throw exception;
    }

    writeIndex(index);
  }
}
