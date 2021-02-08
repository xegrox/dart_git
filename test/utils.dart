import 'dart:io';
import 'package:path/path.dart' as p;

Directory rootDir = (p.basename(Directory.current.path) == 'test') ? Directory.current.parent : Directory.current;

File fixture(String name) => File(p.join(rootDir.path, 'test', 'fixtures', name));