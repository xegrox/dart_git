import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_git/src/exceptions.dart';

enum GitConfigOptionType {
  boolean,
  integer,
  pathname,
  string
}

class GitConfigOption {
  final String section;
  final String name;
  final value;

  GitConfigOption(this.section, this.name, this.value) {
    getParsedValue(); // Check if config value is invalid
  }

  Map<String, GitConfigOptionType> _optionsCore = {
    'repositoryformatversion': GitConfigOptionType.integer,
    'filemode': GitConfigOptionType.boolean,
    'symlinks': GitConfigOptionType.boolean,
    'bare': GitConfigOptionType.boolean,
    'logallrefupdates': GitConfigOptionType.boolean,
  };

  Map<String, GitConfigOptionType> _optionsUser = {
    'name': GitConfigOptionType.string,
    'email': GitConfigOptionType.string,
  };

  getParsedValue() {
    var exception = BadNumericConfigValueException(this.name, this.value.toString());
    var value = this.value.toString();
    switch (this.getType()) {
      case GitConfigOptionType.boolean:
        var regexTrue = RegExp(r'yes|on|true|1');
        var regexFalse = RegExp(r'no|off|false|0');
        if (regexTrue.hasMatch(value)) return true;
        else if (regexFalse.hasMatch(value)) return false;
        else throw exception;
        break;
      case GitConfigOptionType.integer:
        var scale = 1;
        var nValue = value;
        if (nValue.endsWith('k')) scale = 1024;
        else if (nValue.endsWith('M')) scale = 1024*1024;
        if (scale != 1) nValue = value.substring(0, value.length-2);
        var parseInt = int.tryParse(nValue);
        if (parseInt == null) throw exception;
        else return parseInt * scale;
        break;
      case GitConfigOptionType.pathname:
        return value;
        break;
      case GitConfigOptionType.string:
        return value;
        break;
    }
    return value;
  }

  GitConfigOptionType getType() {
    switch (section) {
      case 'core': return _optionsCore[name];
      case 'user': return _optionsUser[name];
    }
    return null;
  }
}

class GitConfigSection {

  final String name;
  GitConfigSection(this.name);
  Map<String, GitConfigOption> _options = {};

  set(String name, dynamic value) {
    var exception = BadNumericConfigValueException(name, value.toString());
    var option = GitConfigOption(this.name, name, value);
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(name)) throw exception; // Check name
    _options[name] = option;
  }

  getRaw(String name) => _options[name].value;
  getParsed(String name) => _options[name].getParsedValue();

  remove(String name) => _options.remove(name);

}

class GitConfig {
  Map<String, GitConfigSection> _sections = {};

  GitConfig();
  GitConfig.fromBytes(Uint8List data) {
    var lines = ascii.decode(data).split('\n');

    GitConfigSection currentSection;
    for (var i = 0; i < lines.length; i++) {
      var exception = BadConfigLineException(i+1);
      var line = lines[i].trim();
      var splitLine = line.split('=');
      var commentIndex = line.indexOf(RegExp(r'[#;]'));
      if (commentIndex == -1) commentIndex = line.length;
      line = line.substring(0, commentIndex);

      if (line.isEmpty) continue;
      else if (line[0] == '[') {
        if (line[line.length - 1] != ']') throw exception;
        var header = line.substring(1, line.length-1).trim();
        currentSection = this.addSection(header);
        continue;
      }
      else if (splitLine.length == 2) {
        var name = splitLine[0].trim();
        var value = splitLine[1].trim();
        // Throw parsing errors
        if (!RegExp(r'^[a-zA-Z]+$').hasMatch(name)) throw exception;
        currentSection.set(name, value);
        continue;
      }
      throw exception;
    }
  }

  GitConfigSection addSection(String name) {
    var section = GitConfigSection(name);
    _sections[name] = section;
    return section;
  }

  GitConfigSection getSection(String name) => _sections[name];

  Uint8List serialize() {
    var contents = [];
    _sections.forEach((name, section) {
      contents.add('[${section.name}]');
      section._options.forEach((name, option) {
        contents.add('\t$name = ${option.value}');
      });
      contents[contents.length-1] += '\n';
    });
    return ascii.encode(contents.join('\n') + '\n');
  }
}