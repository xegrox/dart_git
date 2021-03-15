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
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/reference.dart';

class GitRepo {
  GitRepo(this.dir) {
    validate();
  }

  final Directory dir;

  Directory getGitDir() => Directory(p.join(dir.path, '.git'));

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

    gitDir.createSync();

    // Init git config
    var config = GitConfig();
    var configSection = config.addSection('core');
    configSection.set('repositoryformatversion', 0);
    var configFileMode = (Platform.isWindows) ? false : true;
    configSection.set('filemode', configFileMode);
    configSection.set('bare', bare);
    if (!bare) configSection.set('logallrefupdates', true);

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

    // Create and write files
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
      file.createSync();
      file.writeAsStringSync(contents);
    });
    writeConfig(config);
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
      if (signature != GitObjectSignature.commit &&
          signature != GitObjectSignature.tree &&
          signature != GitObjectSignature.blob) {
        throw CorruptObjectException('Invalid header signature \'$signature\'');
      }

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
        default:
          throw CorruptObjectException('Invalid header signature \'$signature\'');
      }
    } on CorruptObjectException catch (e) {
      throw CorruptObjectException(e.message + ' [$hash]');
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

  GitReference readReference(String pathSpec) => _readReference(pathSpec, true);

  GitReference _readReference(String pathSpec, bool mustMatch) {
    var file = File(p.join(getGitDir().path, pathSpec));
    if (!file.existsSync()) {
      if (mustMatch) throw PathSpecNoMatchException(pathSpec);
      return GitReferenceHash(pathSpec, null);
    }

    var data = file.readAsStringSync().trim();
    var symRefPrefix = 'ref:';
    if (data.startsWith(symRefPrefix)) {
      var target = _readReference(data.substring(symRefPrefix.length).trim(), false);
      return GitReferenceSymbolic(pathSpec, target);
    } else {
      var isHash = RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(data);
      if (isHash) return GitReferenceHash(pathSpec, GitHash(data));
      throw BrokenReferenceException(pathSpec);
    }
  }

  void writeReference(GitReference ref, [bool recursive = true]) {
    var file = File(p.join(getGitDir().path, ref.pathSpec));
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
    if (!file.existsSync()) file.createSync();
    file.writeAsBytesSync(ref.serialize());
    if (ref is GitReferenceSymbolic && recursive) {
      writeReference(ref.target, true);
    }
  }

  GitReference readHEAD() => readReference('HEAD');
}

extension RepoTree on GitRepo {
  Directory get branchFolder => Directory(p.join(getGitDir().path, 'branches'));

  Directory get refFolder => Directory(p.join(getGitDir().path, 'refs'));

  Directory get refTagsFolder => Directory(p.join(refFolder.path, 'tags'));

  Directory get refHeadsFolder => Directory(p.join(refFolder.path, 'heads'));

  Directory get refRemotesFolder => Directory(p.join(refFolder.path, 'remotes'));

  Directory get objectsFolder => Directory(p.join(getGitDir().path, 'objects'));

  Directory get objectsInfoFolder => Directory(p.join(objectsFolder.path, 'info'));

  Directory get objectsPackFolder => Directory(p.join(objectsFolder.path, 'pack'));

  Directory get infoFolder => Directory(p.join(getGitDir().path, 'info'));

  //Files
  File get descFile => File(p.join(getGitDir().path, 'description'));

  File get configFile => File(p.join(getGitDir().path, 'config'));

  File get headFile => File(p.join(getGitDir().path, 'HEAD'));

  File get infoExcludeFile => File(p.join(infoFolder.path, 'exclude'));

  File get indexFile => File(p.join(getGitDir().path, 'index'));
}
