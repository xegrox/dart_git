import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';

extension Add on GitRepo {
  void add(File file) {
    validate();
    if (!p.isWithin(dir.path, file.path)) throw PathSpecOutsideRepoException(dir.path, file.path);
    var index = readIndex();

    var content = file.readAsBytesSync();
    var blob = GitBlob.fromBytes(content);
    writeObject(blob);

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

    var mode = GitFileMode(stat.mode);
    switch (stat.type) {
      case FileSystemEntityType.file:
        mode = GitFileMode.Regular;
        break;
      case FileSystemEntityType.directory:
        mode = GitFileMode.Dir;
        break;
      case FileSystemEntityType.link:
        mode = GitFileMode.Symlink;
        break;
    }

    var indexEntry = GitIndexEntry(
        version: index.version,
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
        path: p.relative(file.path, from: dir.path));

    index.addEntry(indexEntry);
    writeIndex(index);
  }
}
