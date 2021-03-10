import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
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

  File file_1;
  File file_2;
  File file_3;

  test('Test git add', () {
    final blob_path_1 = 'blob_1.txt';
    final blob_path_2 = 'blob_2.txt';
    final blob_path_3 = 'blob_3.txt';

    file_1 = fixture(blob_path_1).copySync(p.join(repo.dir.path, blob_path_1));
    file_2 = fixture(blob_path_2).copySync(p.join(repo.dir.path, blob_path_2));
    file_3 = fixture(blob_path_3).copySync(p.join(repo.dir.path, blob_path_3));

    repo.add(file_2);
    var entries = repo.readIndex().getEntries();
    expect(entries.length, 1);
    expect(entries[0].hash, TestObjHashes.blob_2);

    repo.add(repo.dir);
    entries = repo.readIndex().getEntries();
    expect(entries.length, 3);
    expect(entries[0].hash, TestObjHashes.blob_1);
    expect(entries[1].hash, TestObjHashes.blob_2);
    expect(entries[2].hash, TestObjHashes.blob_3);

    // Repeat to ensure no extra entries are added
    repo.add(file_1);
    repo.add(file_2);
    repo.add(file_3);

    repo.add(repo.getGitDir()); // Should not do anything
    entries = repo.readIndex().getEntries();
    expect(entries.length, 3);
    expect(entries[0].hash, TestObjHashes.blob_1);
    expect(entries[1].hash, TestObjHashes.blob_2);
    expect(entries[2].hash, TestObjHashes.blob_3);

    var file_4 = File(p.join(repo.dir.path, 'test')); // Non existent file
    expect(() => repo.add(file_4), throwsA(TypeMatcher<PathSpecNoMatchException>()));
  });

  test(('Test git commit'), () {
    var config = repo.readConfig();
    var section = config.addSection('user');
    section.set('name', 'XeGrox');
    section.set('email', 'xegrox@protonmail.com');
    repo.writeConfig(config);
    repo.commit('Initial commit');
    expect(() => repo.commit(''), throwsA(TypeMatcher<NothingToCommitException>()));
  });

  test(('Test git remove'), () {
    // Remove from index only
    repo.rm(file_2, cached: true);
    var entries = repo.readIndex().getEntries();
    expect(entries.length, 2);
    expect(entries[0].hash, TestObjHashes.blob_1);
    expect(entries[1].hash, TestObjHashes.blob_3);
    expect(file_2.existsSync(), true);

    // Remove file and index entry
    repo.rm(sandboxDir, cached: false);
    entries = repo.readIndex().getEntries();
    var contents = sandboxDir.listSync();
    expect(contents.any((e) => e.path == repo.getGitDir().path), true);
    expect(contents.any((e) => e.path == file_2.path), true);
    expect(entries.length, 0);

    expect(() => repo.rm(file_1), throwsA(TypeMatcher<PathSpecNoMatchException>()));
    expect(() => repo.rm(file_2), throwsA(TypeMatcher<PathSpecNoMatchException>()));
    expect(() => repo.rm(file_3), throwsA(TypeMatcher<PathSpecNoMatchException>()));
  });

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}
