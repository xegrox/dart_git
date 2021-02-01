import 'dart:io';
import 'package:dart_git/src/git_repo.dart';

class GitConfigSection {

  final String name;
  GitConfigSection(this.name);
  Map<String, String> _options = {};

  /// Sets option in current section. Option is created if it didn't exist. 
  set(String name, String value) => _options[name] = value;

  /// Removes option from current section. Returns false if it doesn't exists, if not return true
  bool remove(String name) => _options.remove(name) != null;

}

class GitConfig {

  List<GitConfigSection> _sections = [];

  GitConfigSection addSection(String name) {
    var section = GitConfigSection(name);
    _sections.add(section);
    return section;
  }

  Future<void> writeToFile(File file) async {
    var contents = [];
    _sections.asMap().forEach((index, section) {
      if (index > 0) contents.add('\n'); // Separate sections with newlines
      contents.add('[${section.name}]');
      section._options.forEach((name, value) { 
        contents.add('\t$name = $value');
      });
    });
    await file.writeAsString(contents.join('\n') + '\n');
  }

  Future<void> writeToRepo(GitRepo repo) async {
    var file = RepoTree(repo).configFile;
    if (!file.existsSync()) file.create();
    await writeToFile(RepoTree(repo).configFile);
  }

  Future<GitConfig> loadFromFile(File file) async {

  }
  Future<GitConfig> loadFromRepo(GitRepo repo) async {

  }
}