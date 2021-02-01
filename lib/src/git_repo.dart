import 'dart:io';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';

class GitRepo {
  GitRepo({
    @required this.dir,
    @required this.config,
  });

  final Directory dir;
  final GitConfig config;
  Directory getGitDir() => Directory(p.join(dir.path, '.git'));
  GitIndex readIndex() => (indexFile.existsSync()) ? GitIndex.fromBytes(indexFile.readAsBytesSync()) : GitIndex(entries: {}, version: 2);
  Future<File> writeIndex(GitIndex index) => indexFile.writeAsBytes(index.serialize());

  validate() {
    var exception = InvalidGitRepositoryException(this.dir.path);
    // Check if HEAD file is a symlink
    if (FileSystemEntity.isLinkSync(this.headFile.path)) {
      var linkPath = this.headFile.resolveSymbolicLinksSync();
      if (p.isWithin(this.refFolder.path, linkPath)) throw exception;
    } else {
      // Check if HEAD file contains valid ref
      var headFileContents = this.headFile.readAsStringSync();
      var validRef = headFileContents.startsWith('ref: refs/');
      // Check if HEAD is detached
      var isDetached = RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(headFileContents);
      if (!validRef && !isDetached) throw exception;
    }
  }

  static Future<GitRepo> init(Directory dir, {bool bare = false}) async {
    var gitDir = bare ? dir : Directory(p.join(dir.path, '.git'));

    await gitDir.create();

    // Init git config
    var config = GitConfig();
    var configSection = config.addSection('core');
    configSection.set('repositoryformatversion', '0');
    configSection.set('filemode', 'true');
    configSection.set('bare', bare.toString());
    if (!bare) configSection.set('logallrefupdates', 'true');

    var repo = GitRepo(dir: dir, config: config );

    // Create directories
    var dirList = [
      repo.branchFolder,
      repo.refFolder,
      repo.refTagsFolder,
      repo.refHeadsFolder,
      repo.objectsFolder,
      repo.objectsInfoFolder,
      repo.objectsPackFolder,
      repo.infoFolder,
    ];

    for (var dir in dirList) {
      await dir.create();
    }

    // Create and write files
    var fileList = <File, String>{
      File(p.join(repo.getGitDir().path, 'description')): "Unnamed repository; edit this file 'description' to name the repository.\n",
      repo.headFile: 'ref: refs/heads/master\n',
      repo.infoExcludeFile:
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
    config.writeToRepo(repo);
    return repo;
  }

  writeObject(GitObject object) {
    var hash = object.hash.toString();
    var dir = Directory(p.join(this.objectsFolder.path, hash.substring(0, 2)));
    var file = File(p.join(dir.path, hash.substring(2, hash.length)));
    dir.createSync();
    file.createSync();

    var data = object.serialize();
    var compressedData = ZLibCodec(level: 1).encode(data);
    file.writeAsBytesSync(compressedData);
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