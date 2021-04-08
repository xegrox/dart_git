import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tag.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/reference.dart';

class GitRepo {
  GitRepo(this.dir) {
    validate();
  }

  final Directory dir;

  Directory get dotGitDir => Directory(p.join(dir.path, '.git'));

  void validate() {
    var exception = InvalidGitRepositoryException(dir.path);
    if (!headFile.existsSync()) throw exception;
    var data = headFile.readAsStringSync().trim();
    var symRefPrefix = 'ref:';
    if (data.startsWith(symRefPrefix)) {
      var refPathSpec = data.substring(symRefPrefix.length).trim();
      if (RegExp(r'^refs/.').hasMatch(refPathSpec)) ;
    } else {
      if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(data)) throw exception;
    }
  }

  GitRepo.init(this.dir, {bool bare = false}) {
    var gitDir = bare ? dir : Directory(p.join(dir.path, '.git'));

    gitDir.createSync(recursive: true);

    // Write git config
    var config = readConfig();
    var section = 'core';
    config.setValue(section, 'repositoryformatversion', '0');
    config.setValue(section, 'filemode', (!Platform.isWindows).toString());
    config.setValue(section, 'bare', bare.toString());
    if (!bare) config.setValue(section, 'logallrefupdates', true.toString());
    writeConfig(config);

    // Create directories
    var dirList = [
      branchFolder,
      refFolder,
      refTagsFolder,
      refHeadsFolder,
      objectsFolder,
      objectsInfoFolder,
      objectsPackFolder,
      infoFolder,
    ];

    for (var dir in dirList) {
      dir.createSync();
    }

    // Create and write files if not exists
    var fileList = <File, String>{
      descFile: "Unnamed repository; edit this file 'description' to name the repository.\n",
      headFile: 'ref: refs/heads/master\n',
      infoExcludeFile: r'''
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
'''
    };

    fileList.forEach((file, contents) {
      if (file.existsSync()) return;
      file.createSync();
      file.writeAsStringSync(contents);
    });
  }

  GitConfig readConfig() => (configFile.existsSync()) ? GitConfig.fromBytes(configFile.readAsBytesSync()) : GitConfig();

  void writeConfig(GitConfig config) {
    if (!configFile.existsSync()) configFile.createSync();
    configFile.writeAsBytesSync(config.serialize());
  }

  GitIndex readIndex() => (indexFile.existsSync()) ? GitIndex.fromBytes(indexFile.readAsBytesSync()) : GitIndex([]);

  void writeIndex(GitIndex index) {
    if (!indexFile.existsSync()) indexFile.createSync();
    indexFile.writeAsBytesSync(index.serialize());
  }

  File _objectFileFromHash(GitHash hash) {
    var h = hash.toString();
    var dir = Directory(p.join(objectsFolder.path, h.substring(0, 2)));
    return File(p.join(dir.path, h.substring(2, h.length)));
  }

  GitObject readObject(GitHash hash) {
    var compressedData = _objectFileFromHash(hash).readAsBytesSync();
    var data = Uint8List.fromList(zlib.decode(compressedData));
    try {
      var headerLength = data.indexOf(0x00);
      if (headerLength == -1) throw CorruptObjectException('Missing header');
      var header = ascii.decode(data.sublist(0, data.indexOf(0x00)));

      var split = header.split(' ');
      if (split.length != 2) throw CorruptObjectException('Invalid header $header');

      var signature = split[0];

      var cLength = int.tryParse(split[1]);
      if (cLength == null) throw CorruptObjectException('Invalid length \'$cLength\'');
      var content = data.sublist(headerLength + 1);
      if (content.length != cLength) {
        throw CorruptObjectException('Invalid length \'$cLength\' does not match actual length \'${content.length}\'');
      }

      switch (signature) {
        case GitObjectSignature.commit:
          return GitCommit.fromBytes(content);
        case GitObjectSignature.tree:
          return GitTree.fromBytes(content);
        case GitObjectSignature.blob:
          return GitBlob.fromBytes(content);
        case GitObjectSignature.tag:
          return GitTag.fromBytes(content);
        default:
          throw CorruptObjectException('Invalid header signature \'$signature\'');
      }
    } on CorruptObjectException catch (e) {
      throw CorruptObjectException(e.msg + ' [$hash]');
    }
  }

  void writeObject(GitObject object) {
    var hash = object.hash;
    var file = _objectFileFromHash(hash);
    objectsFolder.create();
    file.parent.create();
    file.create();

    var data = object.serialize();
    var compressedData = ZLibCodec(level: 1).encode(data);
    file.writeAsBytesSync(compressedData);
  }

  GitReference readReference(String pathSpec) {
    var pathSpecMustMatch = true;
    GitReference _readReference(String pathSpec) {
      var file = File(p.join(dotGitDir.path, pathSpec));
      if (!file.existsSync()) {
        if (pathSpecMustMatch) throw PathSpecNoMatchException(pathSpec);
        return GitReferenceHash(pathSpec.split('/'), null);
      }

      var data = file.readAsStringSync().trim();
      var symRefPrefix = 'ref:';

      if (data.startsWith(symRefPrefix)) {
        pathSpecMustMatch = false;
        var target = _readReference(data.substring(symRefPrefix.length).trim());
        return GitReferenceSymbolic(pathSpec.split('/'), target);
      } else {
        var isHash = RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(data);
        if (isHash) return GitReferenceHash(pathSpec.split('/'), GitHash(data));
        throw BrokenReferenceException(pathSpec);
      }
    }

    return _readReference(pathSpec);
  }

  void writeReference(GitReference ref, [bool recursive = true]) {
    var file = File(p.join(dotGitDir.path, ref.pathSpec.join('/')));
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    if (!file.existsSync()) file.createSync();
    file.writeAsBytesSync(ref.serialize());
    if (ref is GitReferenceSymbolic && recursive) {
      writeReference(ref.target, true);
    }
  }

  bool deleteReference(List<String> pathSpec) {
    var file = File(p.join(dotGitDir.path, pathSpec.join('/')));
    try {
      file.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  GitReference readHEAD() => readReference('HEAD');
}

extension RepoTree on GitRepo {
  Directory get branchFolder => Directory(p.join(dotGitDir.path, 'branches'));

  Directory get refFolder => Directory(p.join(dotGitDir.path, 'refs'));

  Directory get refTagsFolder => Directory(p.join(refFolder.path, 'tags'));

  Directory get refHeadsFolder => Directory(p.join(refFolder.path, 'heads'));

  Directory get refRemotesFolder => Directory(p.join(refFolder.path, 'remotes'));

  Directory get objectsFolder => Directory(p.join(dotGitDir.path, 'objects'));

  Directory get objectsInfoFolder => Directory(p.join(objectsFolder.path, 'info'));

  Directory get objectsPackFolder => Directory(p.join(objectsFolder.path, 'pack'));

  Directory get infoFolder => Directory(p.join(dotGitDir.path, 'info'));

  //Files
  File get descFile => File(p.join(dotGitDir.path, 'description'));

  File get configFile => File(p.join(dotGitDir.path, 'config'));

  File get headFile => File(p.join(dotGitDir.path, 'HEAD'));

  File get infoExcludeFile => File(p.join(infoFolder.path, 'exclude'));

  File get indexFile => File(p.join(dotGitDir.path, 'index'));
}
