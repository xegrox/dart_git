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
    try {
      readHEAD();
    } catch (e) {
      throw exception;
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

  GitIndex readIndex() =>
      (indexFile.existsSync()) ? GitIndex.fromBytes(indexFile.readAsBytesSync()) : GitIndex(entries: {}, version: 2);

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

    var headerLength = data.indexOf(0x00);
    if (headerLength == -1) throw GitObjectException('Missing header');
    var header = ascii.decode(data.sublist(0, data.indexOf(0x00)));

    var split = header.split(' ');

    var signature = split[0];
    if (split.length != 2) throw GitObjectException('Invalid header $header');
    if (signature != GitObjectSignature.commit &&
        signature != GitObjectSignature.tree &&
        signature != GitObjectSignature.blob) {
      throw GitObjectException('Invalid header signature \'$signature\'');
    }

    var content = data.sublist(headerLength + 1);
    var cLength = int.tryParse(split[1]);
    if (cLength == null) throw GitObjectException('Invalid length \'$cLength\'');
    if (content.length != cLength) {
      throw GitObjectException('Invalid length \'$cLength\' does not match actual length \'${content.length}\'');
    }

    switch (signature) {
      case GitObjectSignature.commit:
        return GitCommit.fromBytes(content);
      case GitObjectSignature.tree:
        return GitTree.fromBytes(content);
      case GitObjectSignature.blob:
        return GitBlob.fromBytes(content);
      default:
        throw GitObjectException('Invalid header signature \'$signature\'');
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

  GitReference readHEAD() {
    if (!headFile.existsSync()) throw InvalidGitRepositoryException(dir.path);
    var symbolicRefPrefix = 'ref:';
    var data = headFile.readAsStringSync();
    if (headFile.statSync().type == FileSystemEntityType.link) {
      var symlinkPath = headFile.resolveSymbolicLinksSync();
      symlinkPath = p.relative(symlinkPath, from: getGitDir().path);
      data = '$symbolicRefPrefix $symlinkPath';
    }
    if (data.startsWith(symbolicRefPrefix)) {
      return GitReference.fromLink(this, data);
    } else {
      return GitReference.fromHash(this, GitHash(data));
    }
  }
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
