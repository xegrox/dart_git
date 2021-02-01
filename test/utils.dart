import 'dart:io';
import 'package:path/path.dart' as p;

Directory rootDir = (p.basename(Directory.current.path) == 'test') ? Directory.current.parent : Directory.current;

Future<Directory> setupSandbox() async {
  return await Directory(p.join(rootDir.path, 'test_sandbox')).create();
}

File fixture(String name) => File(p.join(rootDir.path, 'test', 'fixtures', name));