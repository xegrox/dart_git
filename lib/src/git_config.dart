import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';

abstract class GitConfigValue {
  final String rawValue;

  dynamic get value;

  GitConfigValue(this.rawValue);
}

class GitConfigValueBool extends GitConfigValue with EquatableMixin {
  GitConfigValueBool(String raw) : super(raw);

  @override
  bool get value {
    var regexTrue = RegExp(r'yes|on|true|1');
    var regexFalse = RegExp(r'no|off|false|0');
    if (regexTrue.hasMatch(rawValue)) return true;
    if (regexFalse.hasMatch(rawValue)) return false;
    throw GitException('Bad value for boolean \'$rawValue\'');
  }

  @override
  List<Object> get props => [value];
}

class GitConfigValueInt extends GitConfigValue with EquatableMixin {
  GitConfigValueInt(String raw) : super(raw);

  @override
  int get value {
    var regex = RegExp(r'^([0-9]+)([kmg])?$', caseSensitive: false);
    var match = regex.firstMatch(rawValue);
    if (match == null) throw GitException('Bad value for int \'$rawValue\'');
    var value = int.parse(match[1]!);
    var unit = match[2];
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
    return value;
  }

  @override
  List<Object> get props => [value];
}

class GitConfigValueColor extends GitConfigValue with EquatableMixin {
  GitConfigValueColor(String raw) : super(raw);

  // TODO: parse config color value
  @override
  String get value => rawValue;

  @override
  List<Object> get props => [value];
}

class GitConfigValuePath extends GitConfigValue with EquatableMixin {
  GitConfigValuePath(String raw) : super(raw);

  @override
  String get value => rawValue;

  @override
  List<Object> get props => [value];
}

class GitConfigValueString extends GitConfigValue with EquatableMixin {
  GitConfigValueString(String raw) : super(raw);

  @override
  String get value => rawValue;

  @override
  List<Object> get props => [value];
}

class _RawValuesKey extends Equatable {
  final String section;
  final String? subsection;
  final String name;

  _RawValuesKey(this.section, this.subsection, this.name);

  // Support deprecated subsection format (section.subsection)
  @override
  List<Object> get props => ['$section${(subsection != null) ? '.$subsection' : ''}', name];
}

class GitConfig {
  final _values = <_RawValuesKey, List<String?>>{};

  GitConfig();

  factory GitConfig.fromBytes(Uint8List data) {
    var config = GitConfig();
    var lines = ascii.decode(data).split(RegExp('\n'));

    String? currentSection;
    String? currentSubsection;
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

        currentSection = match[1]!.toLowerCase();
        currentSubsection = null;

        // Parse subsection
        // Throw exception if subsection ends with '\', or contains unescaped '"'
        // Escape any character that is preceded by '\'

        var rawSubsection = match[2];
        if (rawSubsection != null) {
          currentSubsection = '';
          for (var p = 0; p < rawSubsection.length; p++) {
            var c = rawSubsection[p];
            if (c == r'\') {
              if (++p >= rawSubsection.length) throw exception;
              currentSubsection = currentSubsection! + rawSubsection[p];
            } else if (c == '"') {
              throw exception;
            } else {
              currentSubsection = currentSubsection! + c;
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
      if (!RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(name)) throw exception;

      // Parse value
      String? value;
      if (valueIndex != -1) {
        var fmtValue = '';
        var rawValue = line.substring(valueIndex + 1, line.length).trim();

        // Format value
        var quote = false;
        var space = 0;
        for (var p = 0; p < rawValue.length; p++) {
          var c = rawValue[p];
          if (c == r'\') {
            if (p == rawValue.length - 1) {
              // TODO: test this
              // '\' is the last char, append next line
              if (++i < line.length - 1) rawValue += lines[i];
              continue;
            }

            c = rawValue[++p];
            switch (c) {
              case 't':
                fmtValue += '\t';
                break;
              case 'b':
                if (fmtValue.isNotEmpty) fmtValue = fmtValue.substring(0, fmtValue.length - 1);
                break;
              case 'n':
                fmtValue += '\n';
                break;
              case r'\':
              case '"':
                fmtValue += c;
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

          fmtValue += ''.padLeft(space);
          space = 0;

          fmtValue += c;
        }
        if (quote) throw exception;
        value = fmtValue;
      }

      if (currentSection == null) throw exception;
      config.addValue(currentSection, name, value, subsection: currentSubsection);
    }
    return config;
  }

  void addValue(String section, String name, String? value, {String? subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    _values.putIfAbsent(key, () => []).add(value);
  }

  void setValue(String section, String name, String? value, {String? subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    _values.putIfAbsent(key, () => [])
      ..clear()
      ..add(value);
  }

  bool containsKey(String section, String name, {String? subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    return _values.containsKey(key);
  }

  List<T?>? getAllValues<T extends GitConfigValue>(String section, String name, {String? subsection}) {
    var key = _RawValuesKey(section, subsection, name);
    // Deprecated section.subsection format
    return _values[key]?.map<T?>((value) {
      if (value == null) return null;
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

  T? getValue<T extends GitConfigValue>(String section, String name, {String? subsection}) {
    var values = getAllValues<T>(section, name, subsection: subsection);
    return values?.last;
  }

  Uint8List serialize() {
    var lines = <String>[];
    // Map<SectionName, Map<VariableName, ListOfValues>>
    var sections = SplayTreeMap<String, Map<String, List<String?>>>();

    // Arrange the values into sections
    _values.forEach((key, values) {
      var sectionName = key.section;
      if (key.subsection != null) sectionName += ' "${key.subsection}"';
      var section = sections.putIfAbsent(sectionName, () => {});
      section[key.name] = values;
    });

    // Format into lines
    sections.forEach((name, variables) {
      lines.add('[$name]');
      variables.forEach((key, values) {
        values.forEach((value) {
          if (value == null) {
            lines.add('\t' + key);
            return;
          }
          // Format value
          var quote = false;
          if (value.isNotEmpty) {
            if (value[0] == ' ' || value[value.length - 1] == ' ') quote = true;
            if (!quote && value.contains(RegExp(r'#|;'))) quote = true;
          }

          var fmtValue = '';
          for (var i = 0; i < value.length; i++) {
            var c = value[i];
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
          lines.add('\t' + key + ' = ' + fmtValue);
        });
      });
      lines.add('');
    });

    return ascii.encode(lines.join('\n'));
  }
}
