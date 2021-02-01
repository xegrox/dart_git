import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_git/dart_git.dart';
import 'package:path/path.dart' as p;
import 'constants.dart';
import 'utils.dart';

void main() {

  Directory sandboxDir;
  GitRepo repo;
  
  setUpAll(() async => sandboxDir = await setupSandbox());

  test('Test git init', () async {
    repo = await GitRepo.init(sandboxDir);
    repo.validate();
  });
  
  test('Test git add', () async {
    var name_1 = 'blob_1.txt';
    var name_2 = 'blob_2.txt';
    var name_3 = 'blob_3.txt';

    var file_1 = fixture(name_1).copySync(p.join(repo.dir.path, name_1));
    var file_2 = fixture(name_2).copySync(p.join(repo.dir.path, name_2));
    var file_3 = fixture(name_3).copySync(p.join(repo.dir.path, name_3));

    await repo.add(file_1);
    await repo.add(file_2);
    await repo.add(file_3);

    var index = repo.readIndex();
    expect(index.entries.length, 3);
    expect(index.entries[name_1].hash.toString(), hashes[name_1]);
    expect(index.entries[name_2].hash.toString(), hashes[name_2]);
    expect(index.entries[name_3].hash.toString(), hashes[name_3]);
  });

  tearDownAll(() => sandboxDir.deleteSync(recursive: true));
}