import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';

abstract class GitConfigValue {}

class GitConfigValueBool extends Equatable implements GitConfigValue {
  final bool value;

  GitConfigValueBool._(this.value);

  factory GitConfigValueBool(String raw) {
    var regexTrue = RegExp(r'yes|on|true|1');
    var regexFalse = RegExp(r'no|off|false|0');
    if (regexTrue.hasMatch(raw)) return GitConfigValueBool._(true);
    if (regexFalse.hasMatch(raw)) return GitConfigValueBool._(false);
    throw GitException('Bad value for boolean \'$raw\'');
  }

  @override
  List<Object> get props => [value];
}

class GitConfigValueInt extends Equatable implements GitConfigValue {
  final int value;

  GitConfigValueInt._(this.value);

  factory GitConfigValueInt(String raw) {
    var regex = RegExp(r'^[0-9]+[kmg]?$', caseSensitive: false);
    if (!regex.hasMatch(raw)) throw GitException('Bad value for int \'$raw\'');

    var value = int.parse(RegExp('^[0-9]').stringMatch(raw));
    var unit = RegExp(r'[kmg]$', caseSensitive: false).stringMatch(raw)?.toLowerCase();
    switch (unit) {
      case 'k':
        value *= 1024;
        break;
      case 'm':
        value *= 1024 * 1024;
        break;
      case 'g':
        value *= 1024 * 1024 * 1024;
        break;
    }
    return GitConfigValueInt._(value);
  }

  @override
  List<Object> get props => [value];
}

class GitConfigValueColor extends Equatable implements GitConfigValue {
  final String value;

  GitConfigValueColor(this.value);

  @override
  List<Object> get props => [value];
}

class GitConfigValuePath extends Equatable implements GitConfigValue {
  final String value;

  GitConfigValuePath(this.value);

  @override
  List<Object> get props => [value];
}

class GitConfigValueString extends Equatable implements GitConfigValue {
  final String value;

  GitConfigValueString(this.value);

  @override
  List<Object> get props => [value];
}

class _RawValuesKey extends Equatable {
  final String section;
  final String subsection;
  final String name;

  _RawValuesKey(this.section, this.subsection, this.name);

  // Support deprecated subsection format (section.subsection)
  @override
  List<Object> get props => ['$section${(subsection != null) ? '.$subsection' : ''}', name];
}

class GitConfig {
  final _values = <_RawValuesKey, List<String>>{};

  GitConfig();

  factory GitConfig.fromBytes(Uint8List data) {
    var config = GitConfig();
    var lines = ascii.decode(data).split(RegExp('\n'));

    String currentSection;
    String currentSubsection;
    for (var i = 0; i < lines.length; i++) {
      var exception = BadConfigLineException(i + 1);
      var line = lines[i].trimLeft();

      // Parse section
      if (line.startsWith('[')) {
        var end = line.indexOf(']');
        if (end == -1) throw exception;
        var s = line.substring(1, end);
        var regex = RegExp(r'^([a-zA-Z0-9-.]+)(?:\s"(.*)")?$');
        var match = regex.firstMatch(s);
        if (match == null) throw exception;

        currentSection = match[1].toLowerCase();
        currentSubsection = null;

        // Parse subsection
        var rawSubsection = match[2];
        if (rawSubsection != null) {
          currentSubsection = '';
          for (var p = 0; p < rawSubsection.length; p++) {
            var c = rawSubsection[p];
            if (c == r'\') {
              p++;
              if (p >= match[2].length) throw exception;
              currentSubsection += rawSubsection[p];
            } else if (c == '"') {
              throw exception;
            } else {
              currentSubsection += c;
            }
          }
        }

        // Remove [section] from line to parse the remaining chars
        line = line.substring(end + 1).trimLeft();
      }

      // Parse name
      var name = line.toLowerCase().trim();
      var valueIndex = line.indexOf('=');
      if (valueIndex != -1) name = line.substring(0, valueIndex).toLowerCase().trim();
      if (name.isEmpty || name.startsWith(RegExp('#|;'))) continue;
      if (!RegExp(r'^[a-z0-9-]*$').hasMatch(name)) throw exception;

      // Parse value
      var value = '';
      if (valueIndex != -1) {
        var rawValue = line.substring(valueIndex + 1, line.length).trim();
        var runes = rawValue.runes;

        // Format value
        var quote = false;
        var space = 0;
        for (var p = 0; p < runes.length; p++) {
          var c = String.fromCharCode(runes.elementAt(p));

          if (c == r'\') {
            if (p == runes.length - 1) {
              // '\' is the last char, append next line
              rawValue = rawValue.substring(0, rawValue.length - 1);
              if (i < line.length - 1) {
                i++;
                rawValue += line[i];
                runes = rawValue.runes;
              }
              continue;
            }
            p++;
            c = String.fromCharCode(runes.elementAt(p));
            switch (c) {
              case 't':
                value += '\t';
                break;
              case 'b':
                if (value.isNotEmpty) value = value.substring(0, value.length - 1);
                break;
              case 'n':
                value += '\n';
                break;
              case r'\':
              case '"':
                value += c;
                break;
              default:
                throw exception;
            }
            continue;
          }

          if (c == '"') {
            quote = !quote;
            continue;
          }

          if (!quote && RegExp(r'\s').hasMatch(c)) {
            space++;
            continue;
          }

          if (!quote && ['#', ';'].contains(c)) break;

          value += ''.padLeft(space);
          space = 0;

          value += c;
        }

        if (quote) throw exception;
      }

      if (currentSection == null) throw exception;
      config.addValue(currentSection, name, value, subsection: currentSubsection);
    }
    return config;
  }

  void addValue(String section, String name, String value, {String subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    _values.putIfAbsent(key, () => []);
    _values[key].add(value);
  }

  void setValue(String section, String name, String value, {String subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    _values.putIfAbsent(key, () => []);
    _values[key].clear();
    _values[key].add(value);
  }

  List<T> getAllValues<T extends GitConfigValue>(String section, String name, {String subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    if (!_values.containsKey(key)) return null;
    // Deprecated section.subsection format
    return _values[key].map<T>((value) {
      try {
        switch (T) {
          case GitConfigValueBool:
            return GitConfigValueBool(value) as T;
          case GitConfigValueInt:
            return GitConfigValueInt(value) as T;
          case GitConfigValueColor:
            return GitConfigValueColor(value) as T;
          case GitConfigValuePath:
            return GitConfigValuePath(value) as T;
          default:
            return GitConfigValueString(value) as T;
        }
      } on GitException {
        throw BadNumericConfigValueException(name, value);
      }
    }).toList();
  }

  T getValue<T extends GitConfigValue>(String section, String name, {String subsection}) {
    var values = getAllValues<T>(section, name, subsection: subsection);
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  Uint8List serialize() {
    var lines = <String>[];
    var sections = SplayTreeMap<String, Map<String, String>>();

    // Arrange the values into sections
    _values.forEach((key, values) {
      var section = key.section;
      if (key.subsection != null) section += ' "${key.subsection}"';
      sections.putIfAbsent(section, () => {});
      if (values.isEmpty) sections[section][key.name] = null;
      values.forEach((value) {
        sections[section][key.name] = value;
      });
    });

    // Format into lines
    sections.forEach((name, keys) {
      lines.add('[$name]');
      keys.forEach((key, value) {
        var line = '\t' + key;
        if (value != null) {
          // Format value
          var quote = false;
          if (value.isNotEmpty) {
            if (value[0] == ' ' || value[value.length - 1] == ' ') quote = true;
            if (!quote && value.contains(RegExp(r'#|;'))) quote = true;
          }

          var fmtValue = '';
          var runes = value.runes;
          for (var i = 0; i < runes.length; i++) {
            var c = String.fromCharCode(runes.elementAt(i));
            switch (c) {
              case '\n':
                fmtValue += r'\n';
                break;
              case '\t':
                fmtValue += r'\t';
                break;
              case '"':
              case r'\':
                fmtValue += r'\' + c;
                break;
              default:
                fmtValue += c;
            }
          }
          if (quote) fmtValue = '"$fmtValue"';
          line += ' = $fmtValue';
        }
        lines.add(line);
      });
      lines.add('');
    });

    return ascii.encode(lines.join('\n'));
  }
}
