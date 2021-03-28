import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/src/exceptions.dart';

enum GitConfigOptionType { boolean, integer, pathname, string }

class GitConfigOption {
  final String section;
  final String name;
  final dynamic value;

  GitConfigOption(this.section, this.name, this.value) {
    getParsedValue(); // Check if config value is invalid
  }

  final Map<String, GitConfigOptionType> _optionsCore = {
    'repositoryformatversion': GitConfigOptionType.integer,
    'filemode': GitConfigOptionType.boolean,
    'symlinks': GitConfigOptionType.boolean,
    'bare': GitConfigOptionType.boolean,
    'logallrefupdates': GitConfigOptionType.boolean,
  };

  final Map<String, GitConfigOptionType> _optionsUser = {
    'name': GitConfigOptionType.string,
    'email': GitConfigOptionType.string,
  };

  dynamic getParsedValue() {
    var valueStr = value.toString();
    var exception = BadNumericConfigValueException(name, valueStr);
    switch (getType()) {
      case GitConfigOptionType.boolean:
        var regexTrue = RegExp(r'yes|on|true|1');
        var regexFalse = RegExp(r'no|off|false|0');
        if (regexTrue.hasMatch(valueStr)) return true;
        if (regexFalse.hasMatch(valueStr)) return false;
        throw exception;
      case GitConfigOptionType.integer:
        var scale = 1;
        var nValue = valueStr;
        if (nValue.endsWith('k')) scale = 1024;
        if (nValue.endsWith('M')) scale = 1024 * 1024;
        if (scale != 1) nValue = valueStr.substring(0, valueStr.length - 2);
        var parseInt = int.tryParse(nValue);
        if (parseInt == null) throw exception;
        return parseInt * scale;
        break;
      case GitConfigOptionType.pathname:
        return valueStr;
        break;
      case GitConfigOptionType.string:
        return valueStr;
        break;
    }
    return valueStr;
  }

  GitConfigOptionType getType() {
    switch (section) {
      case 'core':
        return _optionsCore[name];
      case 'user':
        return _optionsUser[name];
    }
    return null;
  }
}

class GitConfigSection {
  final String name;

  GitConfigSection(this.name);

  final Map<String, GitConfigOption> _options = {};

  void set(String name, dynamic value) {
    var exception = BadNumericConfigValueException(name, value.toString());
    var option = GitConfigOption(this.name, name, value);
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(name)) throw exception; // Check name
    _options[name] = option;
  }

  String getRaw(String name) => _options[name].value.toString();

  dynamic getParsed(String name) => _options[name].getParsedValue();

  void remove(String name) => _options.remove(name);
}

class GitConfig {
  final Map<String, GitConfigSection> _sections = {};

  GitConfig();

  GitConfig.fromBytes(Uint8List data) {
    var lines = ascii.decode(data).split('\n');

    GitConfigSection currentSection;
    for (var i = 0; i < lines.length; i++) {
      var exception = BadConfigLineException(i + 1);
      var line = lines[i].trim();
      var commentIndex = line.indexOf(RegExp(r'[#;]'));
      if (commentIndex == -1) commentIndex = line.length;
      line = line.substring(0, commentIndex);
      var splitLine = line.split('=');

      if (line.isEmpty) {
        continue;
      } else if (line[0] == '[') {
        // Section
        if (line[line.length - 1] != ']') throw exception;
        var header = line.substring(1, line.length - 1).trim();
        currentSection = GitConfigSection(header);
        setSection(currentSection);
        continue;
      } else if (splitLine.length == 2) {
        // Option
        var name = splitLine[0].trim();
        var value = splitLine[1].trim();
        // Throw parsing errors
        if (!RegExp(r'^[a-zA-Z]+$').hasMatch(name)) throw exception;
        currentSection.set(name, value);
        continue;
      } else {
        throw exception;
      }
    }
  }

  void setSection(GitConfigSection section) => _sections[section.name] = section;

  GitConfigSection getSection(String name) => _sections[name];

  Uint8List serialize() {
    var contents = <String>[];
    _sections.forEach((name, section) {
      contents.add('[${section.name}]');
      section._options.forEach((name, option) {
        contents.add('\t$name = ${option.value}');
      });
      contents[contents.length - 1] += '\n';
    });
    return ascii.encode(contents.join('\n') + '\n');
  }
}
