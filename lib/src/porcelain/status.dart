import 'dart:io';

import 'package:dart_git/dart_git.dart';

enum GitFileStatus { newFile, deleted, modified }

extension Status on GitRepo {
  Map<File, GitFileStatus> getStagedFiles() {
    var head = readHEAD();
    var commit = readObject(head.obtainHashRef().hash);
    var index = readIndex();
  }
}
