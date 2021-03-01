import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/git_hash.dart';

Directory rootDir = (p.basename(Directory.current.path) == 'test') ? Directory.current.parent : Directory.current;

File fixture(String name) => File(p.join(rootDir.path, 'tests', 'fixtures', name));

File _objFixture(String name) => File(p.join(rootDir.path, 'tests', 'fixtures', 'objects', name));

abstract class TestObjFiles {
  static final blob_1 = _objFixture('blob_1');
  static final blob_2 = _objFixture('blob_2');
  static final blob_3 = _objFixture('blob_3');
  static final tree_1 = _objFixture('tree_1');
  static final tree_2 = _objFixture('tree_2');
  static final commit_1 = _objFixture('commit_1');
  static final commit_2 = _objFixture('commit_2');
}

abstract class TestObjHashes {
  static final blob_1 = GitHash('e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
  static final blob_2 = GitHash('033b4468fa6b2a9547a70d88d1bbe8bf3f9ed0d5');
  static final blob_3 = GitHash('b042a60ef7dff760008df33cee372b945b6e884e');
  static final tree_1 = GitHash('d26713cd981a265c258388facb6aa42a595f8c98');
  static final tree_2 = GitHash('8627aedabf93da1e96dd5405c97711fc61ce1364');
  static final commit_1 = GitHash('5a65b7a876102096f5832d29d558c2cac23d64eb');
  static final commit_2 = GitHash('84f232cf214c8b5e08ab73562e2e6b771f19e290');
}
