import 'package:collection/collection.dart';
import 'package:dart_git/src/plumbing/index.dart';
import 'package:test/test.dart';

import 'constants.dart';
import 'utils.dart';

void main() {
  var listEq = ListEquality().equals;
  commonIndexReadTest(GitIndex index) {
    var entries = index.entries;

    expect(entries.length, 3);

    var i = 0;
    entries.forEach((path, entry) {
      i++;
      expect(entry.hash.toString(), hashes['blob_$i']);
      expect(entry.device, 2064);
      expect(entry.uid, 1000);
      expect(entry.gid, 1000);
    });

    expect(entries[0].path, 'blob_1.txt');
    expect(entries[1].path, 'blob_2.txt');
    expect(entries[2].path, 'blob_3.txt');

    expect(entries[0].cTime.seconds, 1611463276);
    expect(entries[0].cTime.nanoSeconds, 602562400);
    expect(entries[1].cTime.seconds, 1611463276);
    expect(entries[1].cTime.nanoSeconds, 642562400);
    expect(entries[2].cTime.seconds, 1611463276);
    expect(entries[2].cTime.nanoSeconds, 672562400);

    expect(entries[0].mTime.seconds, 1611463276);
    expect(entries[0].mTime.nanoSeconds, 602562400);
    expect(entries[1].mTime.seconds, 1611463276);
    expect(entries[1].mTime.nanoSeconds, 642562400);
    expect(entries[2].mTime.seconds, 1611463276);
    expect(entries[2].mTime.nanoSeconds, 672562400);

    expect(entries[0].inode, 33735);
    expect(entries[1].inode, 33736);
    expect(entries[2].inode, 33737);
  }

  test('Test git index v2 [read]', () {
    var file = fixture('index_v2');
    var index = GitIndex.fromBytes(file.readAsBytesSync());
    commonIndexReadTest(index);
    expect(index.version, 2);
  });

  test('Test git index v4 [read]', () {
    var file = fixture('index_v4');
    var index = GitIndex.fromBytes(file.readAsBytesSync());
    commonIndexReadTest(index);
    expect(index.version, 4);
  });

  test('Test git index v2 [write]', () {
    var file = fixture('index_v2');
    var rawIndexData = file.readAsBytesSync();
    var index = GitIndex.fromBytes(rawIndexData);
    var genIndexData = index.serialize();
    expect(listEq(genIndexData, rawIndexData), true);
  });

  test('Test git index v4 [write]', () {
    var file = fixture('index_v4');
    var rawIndexData = file.readAsBytesSync();
    var index = GitIndex.fromBytes(rawIndexData);
    var genIndexData = index.serialize();
    expect(listEq(genIndexData, rawIndexData), true);
  });

}