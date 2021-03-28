import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tag.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:dart_git/src/plumbing/reference.dart';
import 'constants.dart';

void main() {
  var sandboxDir = Directory(p.join(rootDir.path, 'test_sandbox'));
  final path_spec_1 = 'blob_1.txt';
  final path_spec_2 = 'blob_2.txt';
  final path_spec_3 = 'blob_3.txt';
  final path_spec_sub_dir = 'another';
  final path_spec_sub_1 = '$path_spec_sub_dir/blob_1.txt';
  final path_spec_sub_2 = '$path_spec_sub_dir/blob_2.txt';
  final path_spec_sub_3 = '$path_spec_sub_dir/blob_3.txt';

  setUpAll(() {
    // Create files
    sandboxDir.create();
    Directory(p.join(sandboxDir.path, path_spec_sub_dir)).create();
    fixture(path_spec_1).copySync(p.join(sandboxDir.path, path_spec_1));
    fixture(path_spec_2).copySync(p.join(sandboxDir.path, path_spec_2));
    fixture(path_spec_3).copySync(p.join(sandboxDir.path, path_spec_3));
    fixture(path_spec_1).copySync(p.join(sandboxDir.path, path_spec_sub_1));
    fixture(path_spec_2).copySync(p.join(sandboxDir.path, path_spec_sub_2));
    fixture(path_spec_3).copySync(p.join(sandboxDir.path, path_spec_sub_3));
  });

  GitRepo repo;

  group('Test git init', () {
    test('When_InitDir_Should_Succeed', () {
      repo = GitRepo.init(sandboxDir);
      repo.validate();
    });

    test('When_ReinitRepo_Should_RetainConfigValues', () {
      var config = repo.readConfig();
      var coreSection = config.getSection('core');
      coreSection.set('dummy', '0');
      coreSection.set('logallrefupdates', false);
      repo.writeConfig(config);

      repo = GitRepo.init(sandboxDir);
      repo.validate();
      config = repo.readConfig();
      coreSection = config.getSection('core');
      expect(coreSection.getRaw('dummy'), '0');
      expect(coreSection.getParsed('logallrefupdates'), true);
    });

    test('When_Commit_Should_ThrowException', () {
      expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
    });
  });

  group('Test git add', () {
    test('When_FileNotExists_Should_ThrowException', () {
      expect(() => repo.add('dummy'), throwsA(TypeMatcher<PathSpecNoMatchException>()));
    });

    test('When_File_Should_AddEntry', () {
      repo.add(path_spec_2);
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 1);
      expect(entries[0].path, path_spec_2);
    });

    test('When_Dir_Should_AddEntriesRecursively', () {
      repo.add(path_spec_sub_dir);
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 4);
      expect(entries[0].path, path_spec_sub_1);
      expect(entries[1].path, path_spec_sub_2);
      expect(entries[2].path, path_spec_sub_3);
      expect(entries[3].path, path_spec_2);
    });

    test('When_All_Should_AddAllEntries', () {
      repo.add('.');
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 6);
      expect(entries[0].path, path_spec_sub_1);
      expect(entries[1].path, path_spec_sub_2);
      expect(entries[2].path, path_spec_sub_3);
      expect(entries[3].path, path_spec_1);
      expect(entries[4].path, path_spec_2);
      expect(entries[5].path, path_spec_3);
    });

    test('When_AddDotGit_Should_DoNothing', () {
      repo.add('.git');
      repo.add('.git/index');
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 6);
    });
  });

  group(('Test git commit'), () {
    test(('When_NoCredentials_Should_ThrowException'), () {
      expect(() => repo.commit('Initial commit'), throwsA(TypeMatcher<MissingCredentialsException>()));
    });

    test(('When_HaveCredentials_Should_CreateRefAndObjects'), () {
      // Write credentials
      var config = repo.readConfig();
      var section = GitConfigSection('user');
      section.set('name', 'dummy');
      section.set('email', 'dummy@mymail.com');
      config.setSection(section);
      repo.writeConfig(config);

      var commitHash = repo.commit('Initial commit');

      var head = repo.readHEAD() as GitReferenceSymbolic; // HEAD
      var headHashRef = head.target as GitReferenceHash; // refs/heads/master
      expect(head.pathSpec, ['HEAD']);
      expect(headHashRef.pathSpec, ['refs', 'heads', 'master']);
      expect(headHashRef.hash, commitHash);

      var commitObj = repo.readObject(commitHash) as GitCommit;
      var rootTreeObj = repo.readObject(commitObj.treeHash) as GitTree;
      var anotherTreeHash = rootTreeObj.entries.firstWhere((e) => e.name == 'another').hash;
      var anotherTreeObj = repo.readObject(anotherTreeHash) as GitTree;
      expect(rootTreeObj.entries.length, 4);
      expect(anotherTreeObj.entries.length, 3);
    });

    test(('When_NoStagedFiles_Should_ThrowException'), () {
      expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
    });
  });

  group(('Test git remove'), () {
    test('When_FileNotExists_Should_ThrowException', () {
      expect(() => repo.rm('dummy'), throwsA(TypeMatcher<PathSpecNoMatchException>()));
    });

    test('When_File_Should_RmEntryAndDeleteFile', () {
      repo.rm(path_spec_1);
      var entries = repo.readIndex().getEntries();
      expect(File(p.join(repo.dir.path, path_spec_1)).existsSync(), false);
      expect(entries.length, 5);
      expect(entries[0].path, path_spec_sub_1);
      expect(entries[1].path, path_spec_sub_2);
      expect(entries[2].path, path_spec_sub_3);
      expect(entries[3].path, path_spec_2);
      expect(entries[4].path, path_spec_3);
    });

    test('When_DeletedFile_Should_RmEntry', () {
      File(p.join(repo.dir.path, path_spec_sub_1)).delete();
      repo.rm(path_spec_sub_1);
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 4);
      expect(entries[0].path, path_spec_sub_2);
      expect(entries[1].path, path_spec_sub_3);
      expect(entries[2].path, path_spec_2);
      expect(entries[3].path, path_spec_3);
    });

    test('When_CachedTrue_Should_RmEntryAndNotDeleteFile', () {
      repo.rm(path_spec_2, cached: true);
      var entries = repo.readIndex().getEntries();
      expect(File(p.join(repo.dir.path, path_spec_2)).existsSync(), true);
      expect(entries.length, 3);
      expect(entries[0].path, path_spec_sub_2);
      expect(entries[1].path, path_spec_sub_3);
      expect(entries[2].path, path_spec_3);
    });

    test('When_OtherFilesInDir_Should_NotDeleteDir', () {
      var dummy = File(p.join(repo.dir.path, path_spec_sub_dir, 'dummy'));
      dummy.createSync();
      repo.rm(path_spec_sub_dir);
      var entries = repo.readIndex().getEntries();
      expect(dummy.existsSync(), true);
      expect(entries.length, 1);
      expect(entries[0].path, path_spec_3);
    });

    test('When_NoOtherFilesInDir_Should_DeleteDir', () {
      repo.add(path_spec_sub_dir); // Adds dummy
      var entries = repo.readIndex().getEntries();
      expect(entries.length, 2);
      expect(entries[0].path, 'another/dummy');
      expect(entries[1].path, path_spec_3);

      repo.rm(path_spec_sub_dir);
      expect(Directory(p.join(repo.dir.path, path_spec_sub_dir)).existsSync(), false);
      entries = repo.readIndex().getEntries();
      expect(entries.length, 1);
      expect(entries[0].path, path_spec_3);
    });

    test('When_All_Should_RmAllEntries', () {
      repo.rm('.');
      var entries = repo.readIndex().getEntries();
      expect(repo.dir.listSync().length, 2); // [.git, blob_2.txt]
      expect(entries.length, 0);
    });
  });

  group('Test git status', () {
    test('When_RemoveFile_Should_StagedDeleted', () {
      var status = repo.status();
      expect(status.getStagedPaths()[path_spec_2], GitFileStatus.deleted);
    });

    test('When_CreateNewFile_Should_UntrackedNewFile', () {
      File(p.join(repo.dir.path, 'dummy')).createSync();
      var status = repo.status();
      expect(status.getUntrackedPaths().contains('dummy'), true);
    });

    test('When_AddNewFile_Should_StagedNewFile', () {
      repo.add('dummy');
      var status = repo.status();
      expect(status.getStagedPaths()['dummy'], GitFileStatus.newFile);
    });

    test('When_ModifyStagedFile_Should_UnstagedModified', () {
      repo.add(path_spec_2);
      File(p.join(repo.dir.path, path_spec_2)).writeAsStringSync('dummy_content');
      var status = repo.status();
      expect(status.getUnstagedPaths()[path_spec_2], GitFileStatus.modified);
    });

    test('When_AddModifiedFile_Should_StagedModified', () {
      repo.add(path_spec_2);
      var status = repo.status();
      expect(status.getStagedPaths()[path_spec_2], GitFileStatus.modified);
    });

    test('When_DeleteStagedFile_Should_UnstagedDeleted', () {
      File(p.join(repo.dir.path, path_spec_2)).delete();
      var status = repo.status();
      expect(status.getUnstagedPaths()[path_spec_2], GitFileStatus.deleted);
    });
  });

  group('Test git tag', () {
    var tagObjHash = TestObjHashes.blob_1;

    test('When_NoAnnotation_Should_CreateRef', () {
      repo.writeTag('tag_1', tagObjHash);
      var tagRef = repo.readReference('refs/tags/tag_1') as GitReferenceHash;
      expect(tagRef.hash, tagObjHash);
    });

    test('When_HaveAnnotation_Should_CreateRefAndObj', () {
      repo.writeTag('tag_2', tagObjHash, 'dummy');
      var tagRef = repo.readReference('refs/tags/tag_2') as GitReferenceHash;
      var tagObj = repo.readObject(tagRef.hash);
      expect(tagObj.signature, GitObjectSignature.tag);
      expect((tagObj as GitTag).objectHash, tagObjHash);
    });

    test('When_DeleteExistingTag_Should_ReturnTrue', () {
      expect(repo.deleteTag('tag_1'), true);
      expect(repo.deleteTag('tag_2'), true);
      expect(() => repo.readReference('refs/tags/tag_1'), throwsA(TypeMatcher<PathSpecNoMatchException>()));
      expect(() => repo.readReference('refs/tags/tag_2'), throwsA(TypeMatcher<PathSpecNoMatchException>()));
    });

    test('When_DeleteNonExistingTag_Should_ReturnFalse', () {
      expect(repo.deleteTag('tag_1'), false);
      expect(repo.deleteTag('tag_2'), false);
    });
  });

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}
