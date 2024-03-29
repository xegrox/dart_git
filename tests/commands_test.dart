import 'dart:io';

import 'package:dart_git/src/git_hash.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_repo.dart' show RepoTree;
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

  late GitRepo repo;

  group('Test init', () {
    test('When_InitDir_Should_Succeed', () {
      repo = GitRepo.init(sandboxDir);
      repo.validate();
    });

    // TODO: mock config modification
    test('When_ReinitRepo_Should_RetainConfigValuesAndModifiedFiles', () {
      var section = 'core';
      var config = repo.readConfig();
      config.setValue(section, 'dummy', '0');
      config.setValue(section, 'logallrefupdates', 'false');
      repo.writeConfig(config);
      var headFile = File(p.join(repo.dotGitDir.path, 'HEAD'));
      headFile.writeAsStringSync('ref: refs/heads/dummy');

      repo = GitRepo.init(sandboxDir);
      repo.validate();

      config = repo.readConfig();
      expect(config.getValue<GitConfigValueInt>(section, 'dummy')!.value, 0);
      expect(config.getValue<GitConfigValueBool>(section, 'logallrefupdates')!.value, true);
      expect(headFile.readAsStringSync(), 'ref: refs/heads/dummy');
      headFile.writeAsStringSync('ref: refs/heads/master');
    });

    test('When_Commit_Should_ThrowException', () {
      expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
    });
  });

  group('Test add', () {
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

  group(('Test commit'), () {
    test(('When_NoCredentials_Should_ThrowException'), () {
      expect(() => repo.commit('Initial commit'), throwsA(TypeMatcher<MissingCredentialsException>()));
    });

    test(('When_HaveCredentials_Should_CreateRefAndObjects'), () {
      // Write credentials
      var config = repo.readConfig();
      var section = 'user';
      config.setValue(section, 'name', 'dummy');
      config.setValue(section, 'email', 'dummy@mymail.com');
      repo.writeConfig(config);

      var commitHash = repo.commit('Initial commit');

      var head = repo.readHEAD() as GitReferenceSymbolic; // HEAD
      var headHashRef = head.target as GitReferenceHash; // refs/heads/master
      expect(head.refName, 'HEAD');
      expect(headHashRef.refName, 'refs/heads/master');
      expect(headHashRef.hash, commitHash);

      var commitObj = repo.readObject<GitCommit>(commitHash);
      var rootTreeObj = repo.readObject<GitTree>(commitObj.treeHash);
      var anotherTreeHash = rootTreeObj.entries.firstWhere((e) => e.name == 'another').hash;
      var anotherTreeObj = repo.readObject<GitTree>(anotherTreeHash);
      expect(rootTreeObj.entries.length, 4);
      expect(anotherTreeObj.entries.length, 3);
    });

    test(('When_NoStagedFiles_Should_ThrowException'), () {
      expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
    });
  });

  group(('Test remove'), () {
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

  group('Test status', () {
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

  group('Test tag', () {
    var tagObjHash = TestObjHashes.blob_1;

    test('When_InvalidName_Should_ThrowException', () {
      expect(() => repo.writeTag('/dummy', tagObjHash), throwsA(TypeMatcher<InvalidTagNameException>()));
    });

    test('When_NoAnnotation_Should_CreateRef', () {
      repo.writeTag('tag_1', tagObjHash);
      var tagRef = repo.readReference('refs/tags/tag_1') as GitReferenceHash;
      expect(tagRef.hash, tagObjHash);
    });

    test('When_HaveAnnotation_Should_CreateRefAndObj', () {
      repo.writeTag('tag_2', tagObjHash, 'dummy');
      var tagRef = repo.readReference('refs/tags/tag_2') as GitReferenceHash;
      var tagObj = repo.readObject<GitTag>(tagRef.hash);
      expect(tagObj.signature, GitObjectSignature.tag);
      expect(tagObj.objectHash, tagObjHash);
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

  group('Test branch', () {
    late GitHash revision;

    test('When_InvalidName_Should_ThrowException', () {
      revision = repo.readHEAD().revParse().hash;
      expect(() => repo.createBranch('/dummy', revision), throwsA(TypeMatcher<InvalidBranchNameException>()));
    });

    test('When_CreateBranch_Should_CreateRef', () {
      var ref = repo.createBranch('dummy', revision);
      expect(File(p.join(repo.refHeadsFolder.path, 'dummy')).existsSync(), true);
      expect(repo.readReference('refs/heads/dummy').revParse(), ref);
    });

    test('When_CreateBranchWithFolder_Should_CreateRef', () {
      var ref = repo.createBranch('dum/dummy', revision);
      expect(File(p.join(repo.refHeadsFolder.path, 'dum/dummy')).existsSync(), true);
      expect(repo.readReference('refs/heads/dum/dummy').revParse(), ref);
    });

    test('When_DeleteBranch_Should_DeleteRef', () {
      repo.deleteBranch('dum/dummy');
      expect(Directory(p.join('refs/heads/dum')).existsSync(), false);
    });
  });

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}
