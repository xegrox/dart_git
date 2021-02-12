import 'dart:io';

import 'package:path/path.dart' as p;

Directory rootDir = (p.basename(Directory.current.path) == 'test') ? Directory.current.parent : Directory.current;

File fixture(String name) => File(p.join(rootDir.path, 'tests', 'fixtures', name));

File objFixture(String name) => File(p.join(rootDir.path, 'tests', 'fixtures', 'objects', name));

bool listEq(List list1, List list2) {
  if (list1.length != list2.length) return false;
  for (var i = 0; i < list1.length; i++) {
    if (list1[i] != list2[i]) return false;
  }
  return true;
}
