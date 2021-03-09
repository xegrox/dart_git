import 'package:test/test.dart';

import 'package:dart_git/src/plumbing/index.dart';
import 'constants.dart';

void main() {
  void commonIndexReadTest(GitIndex index) {
    var entries = index.getEntries();

    expect(entries.length, 3);

    // Common values
    entries.forEach((entry) {
      expect(entry.device, 2064);
      expect(entry.uid, 1000);
      expect(entry.gid, 1000);
    });

    expect(entries[0].path, 'blob_1.txt');
    expect(entries[1].path, 'blob_2.txt');
    expect(entries[2].path, 'blob_3.txt');

    expect(entries[0].hash, TestObjHashes.blob_1);
    expect(entries[1].hash, TestObjHashes.blob_2);
    expect(entries[2].hash, TestObjHashes.blob_3);

    expect(entries[0].cTime.seconds, 1614488763);
    expect(entries[0].cTime.nanoSeconds, 999422600);
    expect(entries[1].cTime.seconds, 1614488779);
    expect(entries[1].cTime.nanoSeconds, 819422600);
    expect(entries[2].cTime.seconds, 1614488813);
    expect(entries[2].cTime.nanoSeconds, 439422600);

    expect(entries[0].mTime.seconds, 1614488763);
    expect(entries[0].mTime.nanoSeconds, 999422600);
    expect(entries[1].mTime.seconds, 1614488754);
    expect(entries[1].mTime.nanoSeconds, 369422600);
    expect(entries[2].mTime.seconds, 1614488813);
    expect(entries[2].mTime.nanoSeconds, 439422600);

    expect(entries[0].inode, 39532);
    expect(entries[1].inode, 39531);
    expect(entries[2].inode, 39533);
  }

  test('Test git index_v2 v2 [read]', () {
    var file = fixture('index_v2');
    var index = GitIndex.fromBytes(file.readAsBytesSync());
    commonIndexReadTest(index);
    expect(index.version, 2);
  });

  test('Test git index_v2 v4 [read]', () {
    var file = fixture('index_v4');
    var index = GitIndex.fromBytes(file.readAsBytesSync());
    commonIndexReadTest(index);
    expect(index.version, 4);
  });

  test('Test git index_v2 v2 [write]', () {
    var file = fixture('index_v2');
    var rawIndexData = file.readAsBytesSync();
    var index = GitIndex.fromBytes(rawIndexData);
    var genIndexData = index.serialize();
    expect(genIndexData, rawIndexData);
  });

  test('Test git index_v2 v4 [write]', () {
    var file = fixture('index_v4');
    var rawIndexData = file.readAsBytesSync();
    var index = GitIndex.fromBytes(rawIndexData);
    var genIndexData = index.serialize();
    expect(genIndexData, rawIndexData);
  });
}
