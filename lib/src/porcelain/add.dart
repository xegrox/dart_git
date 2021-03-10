import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';

GitIndexEntry _fileToEntry(FileSystemEntity file, int indexVersion, GitRepo repo) {
  var path = p.relative(file.path, from: repo.dir.path);
  if (!file.existsSync()) throw PathSpecNoMatchException(path);

  GitFileMode mode;
  Uint8List content;
  if (file is File) {
    mode = GitFileMode.Regular;
    content = file.readAsBytesSync();
  } else if (file is Link) {
    mode = GitFileMode.Symlink;
    content = ascii.encode(file.targetSync());
  }

  var blob = GitBlob.fromBytes(content);
  var stat = file.statSync();

  var cTimeDateTime = stat.changed;
  var cTime = GitTimestamp(
      dateTime: cTimeDateTime,
      seconds: cTimeDateTime.millisecondsSinceEpoch ~/ 1000,
      nanoSeconds: (cTimeDateTime.millisecond * 1000 + cTimeDateTime.microsecond) * 1000);

  var mTimeDateTime = stat.modified;
  var mTime = GitTimestamp(
      dateTime: mTimeDateTime,
      seconds: mTimeDateTime.millisecondsSinceEpoch ~/ 1000,
      nanoSeconds: (mTimeDateTime.millisecond * 1000 + mTimeDateTime.microsecond) * 1000);

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
      print(command);
      var splitOutput = output.replaceAll(r'"', '').split(' ');
      device = int.parse(splitOutput[0]);
      inode = int.parse(splitOutput[1]);
      print('$device + $inode');
    }

    // uid
    command = Process.runSync('id', ['-u'], runInShell: true);
    if (command.exitCode == 0) uid = int.parse(command.stdout.toString());
    print(uid);

    // gid
    command = Process.runSync('id', ['-g'], runInShell: true);
    if (command.exitCode == 0) gid = int.parse(command.stdout.toString());
  }

  repo.writeObject(blob);

  return GitIndexEntry(
      version: indexVersion,
      cTime: cTime,
      mTime: mTime,
      device: device,
      inode: inode,
      mode: mode,
      uid: uid,
      gid: gid,
      fileSize: stat.size,
      hash: blob.hash,
      stage: GitFileStage(0),
      path: path);
}

bool _isRepo(Directory d) {
  try {
    GitRepo(d);
    return true;
  } on InvalidGitRepositoryException {
    return false;
  }
}

extension Add on GitRepo {
  void add(FileSystemEntity entity) {
    validate();
    if (p.isWithin(getGitDir().path, entity.path) || entity.path == getGitDir().path) return;
    if (!p.isWithin(dir.path, entity.path) && entity.path != dir.path) {
      throw PathSpecOutsideRepoException(dir.path, entity.path);
    }

    var index = readIndex();

    if (entity is Link || entity is File) {
      var entry = _fileToEntry(entity, index.version, this);
      index.setEntry(entry);
    } else {
      // Directory
      void addRecursively(Directory d) {
        if (_isRepo(d) && d != dir) {
          // FIXME: handle embedded repo
        } else {
          d.listSync().forEach((entity) {
            if (entity is File || entity is Link) {
              var entry = _fileToEntry(entity, index.version, this);
              index.setEntry(entry);
            } else if (entity is Directory) {
              if (p.basename(entity.path) == '.git') return;
              addRecursively(entity);
            }
          });
        }
      }

      addRecursively(entity as Directory);
    }

    writeIndex(index);
  }
}
