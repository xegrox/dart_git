import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';

bool _isRepo(Directory d) {
  try {
    GitRepo(d);
    return true;
  } on InvalidGitRepositoryException {
    return false;
  }
}

extension Add on GitRepo {
  void add(String pathSpec) {
    validate();
    var fullPath = p.normalize(p.join(dir.path, pathSpec));
    if (!fullPath.startsWith(dir.path)) {
      throw PathSpecOutsideRepoException(dir.path, pathSpec);
    } else if (fullPath.startsWith(dotGitDir.path)) return;

    var index = readIndex();

    FileSystemEntity target;
    var targetType = FileSystemEntity.typeSync(fullPath, followLinks: false);
    switch (targetType) {
      case FileSystemEntityType.file:
        target = File(fullPath);
        break;
      case FileSystemEntityType.link:
        target = Link(fullPath);
        break;
      case FileSystemEntityType.directory:
        target = Directory(fullPath);
        break;
      case FileSystemEntityType.notFound:
        throw PathSpecNoMatchException(pathSpec);
    }

    GitIndexEntry toEntry(FileSystemEntity file, GitFileMode mode, GitHash hash) {
      var relPath = p.relative(file.path, from: dir.path).replaceAll(p.separator, '/');
      var stat = file.statSync();

      var cTimeDateTime = stat.changed;
      var cTime = GitIndexTimestamp(cTimeDateTime.millisecondsSinceEpoch ~/ 1000,
          (cTimeDateTime.millisecond * 1000 + cTimeDateTime.microsecond) * 1000);

      var mTimeDateTime = stat.modified;
      var mTime = GitIndexTimestamp(mTimeDateTime.millisecondsSinceEpoch ~/ 1000,
          (mTimeDateTime.millisecond * 1000 + mTimeDateTime.microsecond) * 1000);

      var device = 0;
      var inode = 0;
      var uid = 0;
      var gid = 0;
      if (Platform.isLinux | Platform.isAndroid | Platform.isMacOS) {
        var option = (Platform.isMacOS) ? '-f' : '-c';
        // %d = device, %i = inode
        var command = Process.runSync('stat', [option, r'"%d %i"', file.path], runInShell: true);
        if (command.exitCode == 0) {
          var output = command.stdout.toString();
          var splitOutput = output.replaceAll(r'"', '').split(' ');
          device = int.parse(splitOutput[0]);
          inode = int.parse(splitOutput[1]);
        }

        // uid
        command = Process.runSync('id', ['-u'], runInShell: true);
        if (command.exitCode == 0) uid = int.parse(command.stdout.toString());

        // gid
        command = Process.runSync('id', ['-g'], runInShell: true);
        if (command.exitCode == 0) gid = int.parse(command.stdout.toString());
      }

      return GitIndexEntry(
          version: index.version,
          cTime: cTime,
          mTime: mTime,
          device: device,
          inode: inode,
          mode: mode,
          uid: uid,
          gid: gid,
          fileSize: stat.size,
          hash: hash,
          stage: GitFileStage(0),
          path: relPath);
    }

    void addRecursively(FileSystemEntity entity) {
      if (entity is File) {
        var mode = GitFileMode.regular;
        var content = entity.readAsBytesSync();
        var blob = GitBlob.fromBytes(content);
        writeObject(blob);
        var entry = toEntry(entity, mode, blob.hash);
        index.setEntry(entry);
      } else if (entity is Link) {
        var mode = GitFileMode.symlink;
        var content = ascii.encode(entity.targetSync());
        var blob = GitBlob.fromBytes(content);
        writeObject(blob);
        var entry = toEntry(entity, mode, blob.hash);
        index.setEntry(entry);
      } else if (entity is Directory) {
        // Check if directory is submodule
        if (_isRepo(entity) && entity.path != dir.path) {
          throw UnimplementedError();
        } else {
          entity.listSync().forEach((e) {
            if (p.basename(e.path) == '.git') return;
            addRecursively(e);
          });
        }
      }
    }

    addRecursively(target);

    writeIndex(index);
  }
}
