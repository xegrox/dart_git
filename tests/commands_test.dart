import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/src/exceptions.dart';
import 'constants.dart';
import 'utils.dart';

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

  test('Test git add', () {
    var name_1 = 'blob_1.txt';
    var name_2 = 'blob_2.txt';
    var name_3 = 'blob_3.txt';

    var file_1 = fixture(name_1).copySync(p.join(repo.dir.path, name_1));
    var file_2 = fixture(name_2).copySync(p.join(repo.dir.path, name_2));
    var file_3 = fixture(name_3).copySync(p.join(repo.dir.path, name_3));

    repo.add(file_1);
    repo.add(file_2);
    repo.add(file_3);

    // Repeat to ensure no extra entries are added
    repo.add(file_1);
    repo.add(file_2);
    repo.add(file_3);

    var index = repo.readIndex();
    expect(index.entries.length, 3);
    expect(index.entries[name_1].hash.toString(), hashes[name_1]);
    expect(index.entries[name_2].hash.toString(), hashes[name_2]);
    expect(index.entries[name_3].hash.toString(), hashes[name_3]);
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

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}
