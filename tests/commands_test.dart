import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tag.dart';
import 'package:dart_git/src/plumbing/reference.dart';
import 'constants.dart';

void main() {
  Directory sandboxDir;
  GitRepo repo;

  setUpAll(() {
    sandboxDir = Directory(p.join(rootDir.path, 'test_sandbox'));
    sandboxDir.createSync();
  });

  test('Test git init', () {
    repo = GitRepo.init(sandboxDir);
    repo.validate();
    expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
  });

  final path_spec_1 = 'blob_1.txt';
  final path_spec_2 = 'blob_2.txt';
  final path_spec_3 = 'blob_3.txt';
  final path_spec_sub_dir = 'another';
  final path_spec_sub_1 = '$path_spec_sub_dir/blob_1.txt';
  final path_spec_sub_2 = '$path_spec_sub_dir/blob_2.txt';
  final path_spec_sub_3 = '$path_spec_sub_dir/blob_3.txt';

  test('Test git add', () {
    // Create files
    Directory(p.join(repo.dir.path, path_spec_sub_dir)).create();
    fixture(path_spec_1).copySync(p.join(repo.dir.path, path_spec_1));
    fixture(path_spec_2).copySync(p.join(repo.dir.path, path_spec_2));
    fixture(path_spec_3).copySync(p.join(repo.dir.path, path_spec_3));
    fixture(path_spec_1).copySync(p.join(repo.dir.path, path_spec_sub_1));
    fixture(path_spec_2).copySync(p.join(repo.dir.path, path_spec_sub_2));
    fixture(path_spec_3).copySync(p.join(repo.dir.path, path_spec_sub_3));

    // Non-existent file
    expect(() => repo.add('dummy'), throwsA(TypeMatcher<PathSpecNoMatchException>()));

    repo.add(path_spec_2);
    var entries = repo.readIndex().getEntries();
    expect(entries.length, 1);
    expect(entries[0].path, path_spec_2);

    repo.add(path_spec_sub_dir);
    entries = repo.readIndex().getEntries();
    expect(entries.length, 4);
    expect(entries[0].path, path_spec_sub_1);
    expect(entries[1].path, path_spec_sub_2);
    expect(entries[2].path, path_spec_sub_3);
    expect(entries[3].path, path_spec_2);

    repo.add('.');
    entries = repo.readIndex().getEntries();
    expect(entries.length, 6);
    expect(entries[0].path, path_spec_sub_1);
    expect(entries[1].path, path_spec_sub_2);
    expect(entries[2].path, path_spec_sub_3);
    expect(entries[3].path, path_spec_1);
    expect(entries[4].path, path_spec_2);
    expect(entries[5].path, path_spec_3);

    repo.add('.git'); // Should not do anything
    repo.add('.git/index');
    entries = repo.readIndex().getEntries();
    expect(entries.length, 6);
  });

  test(('Test git commit'), () {
    var config = repo.readConfig();
    var section = config.addSection('user');
    section.set('name', 'XeGrox');
    section.set('email', 'xegrox@protonmail.com');
    repo.writeConfig(config);
    var commitHash = repo.commit('Initial commit');
    expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));

    var head = repo.readHEAD() as GitReferenceSymbolic; // HEAD
    var headHashRef = head.target as GitReferenceHash; // refs/heads/master
    expect(head.pathSpec, ['HEAD']);
    expect(headHashRef.pathSpec, ['refs', 'heads', 'master']);
    expect(headHashRef.hash, commitHash);
  });

  test(('Test git remove'), () {
    // Non-existent entry
    expect(() => repo.rm('dummy'), throwsA(TypeMatcher<PathSpecNoMatchException>()));

    repo.rm(path_spec_1);
    var entries = repo.readIndex().getEntries();
    expect(File(p.join(repo.dir.path, path_spec_1)).existsSync(), false);
    expect(entries.length, 5);
    expect(entries[0].path, path_spec_sub_1);
    expect(entries[1].path, path_spec_sub_2);
    expect(entries[2].path, path_spec_sub_3);
    expect(entries[3].path, path_spec_2);
    expect(entries[4].path, path_spec_3);

    repo.rm(path_spec_2, cached: true);
    entries = repo.readIndex().getEntries();
    expect(File(p.join(repo.dir.path, path_spec_2)).existsSync(), true);
    expect(entries.length, 4);
    expect(entries[0].path, path_spec_sub_1);
    expect(entries[1].path, path_spec_sub_2);
    expect(entries[2].path, path_spec_sub_3);
    expect(entries[3].path, path_spec_3);

    Directory(p.join(repo.dir.path, path_spec_sub_dir)).deleteSync(recursive: true);
    repo.rm(path_spec_sub_dir);
    entries = repo.readIndex().getEntries();
    expect(Directory(p.join(repo.dir.path, path_spec_sub_dir)).existsSync(), false);
    expect(entries.length, 1);
    expect(entries[0].path, path_spec_3);

    repo.rm('.');
    entries = repo.readIndex().getEntries();
    expect(repo.dir.listSync().length, 2);
    expect(File(p.join(repo.dir.path, path_spec_2)).existsSync(), true);
    expect(entries.length, 0);
  });

  test('Test git tag', () {
    var tagObjHash = TestObjHashes.blob_1;

    // Non-annotated tag
    repo.writeTag('tag_1', tagObjHash);
    var tagRef = repo.readReference('refs/tags/tag_1') as GitReferenceHash;
    expect(tagRef.hash, tagObjHash);

    // Annotated tag
    repo.writeTag('tag_2', tagObjHash, 'dummy');
    tagRef = repo.readReference('refs/tags/tag_2') as GitReferenceHash;
    var tagObj = repo.readObject(tagRef.hash);
    expect(tagObj.signature, GitObjectSignature.tag);
    expect((tagObj as GitTag).objectHash, tagObjHash);

    // Delete tags
    expect(repo.deleteTag('tag_1'), true);
    expect(repo.deleteTag('tag_2'), true);
    expect(repo.deleteTag('tag_1'), false);
    expect(repo.deleteTag('tag_2'), false);
  });

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}
