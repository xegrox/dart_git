import 'dart:io';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/reference.dart';
import 'package:path/path.dart' as p;
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';

enum GitObjectType {
  blob,
  tree,
  commit
}

class GitRepo {
  GitRepo(this.dir) {
    validate();
  }

  Directory dir;

  Directory getGitDir() => Directory(p.join(dir.path, '.git'));

  validate() {
    var exception = InvalidGitRepositoryException(this.dir.path);
    if (!headFile.existsSync()) throw exception;
    try {
      readHEAD();
    } catch (e) {
      throw exception;
    }
  }

  GitRepo.init(Directory dir, {bool bare = false}) {
    this.dir = dir;
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
      this.branchFolder,
      this.refFolder,
      this.refTagsFolder,
      this.refHeadsFolder,
      this.objectsFolder,
      this.objectsInfoFolder,
      this.objectsPackFolder,
      this.infoFolder,
    ];

    for (var dir in dirList) {
      dir.createSync();
    }

    // Create and write files
    var fileList = <File, String>{
      File(p.join(this.getGitDir().path, 'description')): "Unnamed repository; edit this file 'description' to name the repository.\n",
      this.headFile: 'ref: refs/heads/master\n',
      this.infoExcludeFile:
r'''
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
    this.writeConfig(config);
  }

  GitConfig readConfig() => (configFile.existsSync()) ? GitConfig.fromBytes(configFile.readAsBytesSync()) : GitConfig();

  writeConfig(GitConfig config) {
    if (!configFile.existsSync()) configFile.createSync();
    configFile.writeAsBytesSync(config.serialize());
  }

  GitIndex readIndex() => (indexFile.existsSync()) ? GitIndex.fromBytes(indexFile.readAsBytesSync()) : GitIndex(entries: {}, version: 2);

  writeIndex(GitIndex index) {
    if (!indexFile.existsSync()) indexFile.createSync();
    indexFile.writeAsBytesSync(index.serialize());
  }

  File _objectFileFromHash(GitHash hash) {
    var h = hash.toString();
    var dir = Directory(p.join(this.objectsFolder.path, h.substring(0, 2)));
    return File(p.join(dir.path, h.substring(2, h.length)));
  }

  GitObject readObject(GitObjectType type, GitHash hash) {
    var compressedData = _objectFileFromHash(hash).readAsBytesSync();
    var data = zlib.decode(compressedData);
    switch(type) {
      case GitObjectType.blob:
        return GitBlob.fromBytes(data);
      case GitObjectType.tree:
        return GitTree.fromBytes(data);
      case GitObjectType.commit:
        return GitCommit.fromBytes(data);
    }
  }

  writeObject(GitObject object) {
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
    if (!headFile.existsSync()) throw InvalidGitRepositoryException(this.dir.path);
    var symbolicRefPrefix = 'ref:';
    var data = headFile.readAsStringSync();
    if (headFile.statSync().type == FileSystemEntityType.link) {
      var symlinkPath = headFile.resolveSymbolicLinksSync();
      symlinkPath = p.relative(symlinkPath, from: this.getGitDir().path);
      data =  '$symbolicRefPrefix $symlinkPath';
    }
    if (data.startsWith(symbolicRefPrefix)) return GitReference.fromLink(this, data);
    else return GitReference.fromHash(this, GitHash(data));
  }
}

extension RepoTree on GitRepo {
  Directory get branchFolder => Directory(p.join(this.getGitDir().path, 'branches'));
  Directory get refFolder => Directory(p.join(this.getGitDir().path, 'refs'));
  Directory get refTagsFolder => Directory(p.join(refFolder.path, 'tags'));
  Directory get refHeadsFolder => Directory(p.join(refFolder.path, 'heads'));
  Directory get refRemotesFolder => Directory(p.join(refFolder.path, 'remotes'));
  Directory get objectsFolder => Directory(p.join(this.getGitDir().path, 'objects'));
  Directory get objectsInfoFolder => Directory(p.join(objectsFolder.path, 'info'));
  Directory get objectsPackFolder => Directory(p.join(objectsFolder.path, 'pack'));
  Directory get infoFolder => Directory(p.join(this.getGitDir().path, 'info'));

  //Files
  File get configFile => File(p.join(this.getGitDir().path, 'config'));
  File get headFile => File(p.join(this.getGitDir().path, 'HEAD'));
  File get infoExcludeFile => File(p.join(infoFolder.path, 'exclude'));
  File get indexFile => File(p.join(this.getGitDir().path, 'index'));
}