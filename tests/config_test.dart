import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';

void main() {
  group('Test git config [read]', () {
    group('Test config section', () {
      test('When_MissingCloseBracket_Should_ThrowException', () {
        var raw = '[';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));

        raw = '[core';
        bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_Empty_ShouldThrowException', () {
        var raw = '[]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      // Valid characters: a-z, A-Z, 0-9, ., -
      test('When_InvalidCharacter_ShouldThrowException', () {
        var raw = '[core ]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));

        raw = '[ core]';
        bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_ValidCharacter_Should_Succeed', () {
        var raw = '[.-c-O.rE-.]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        GitConfig.fromBytes(bytes);
      });

      test('When_SubsectionValidCharacter_Should_Succeed', () {
        var raw = '[core "dummy"]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        GitConfig.fromBytes(bytes);
      });

      test('When_SubsectionHasDQuote_Should_ThrowException', () {
        var raw = '[core "dumm"y"]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));

        raw = '[core "dumm"y""]';
        bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_SubsectionHasEscapedDQuote_Should_Succeed', () {
        var raw = r'[core "dummy\""]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        GitConfig.fromBytes(bytes);
      });

      test('When_SubsectionEndsWithEscapeChar_Should_ThrowException', () {
        var raw = r'[core "dummy\"]';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });
    });

    group('Test config key', () {
      test('When_VarNameIsComment_Should_SkipLine', () {
        var raw = '#dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        GitConfig.fromBytes(bytes);
      });

      // Section related tests
      test('When_VarHasNoSection_Should_ThrowException', () {
        var raw = 'dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_VarAfterSectionOnSameLine_Should_BelongToSection', () {
        var raw = '[core] dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy'), true);
      });

      test('When_VarAfterSectionOnNewline_Should_BelongToSection', () {
        var raw = '[core]\n dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy'), true);
      });

      test('When_VarSectionHasUppercase_Should_ConvertToLowercase', () {
        var raw = '[cOrE] dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy'), true);
      });

      test('When_VarHasSubsection_Should_BelongToSubsection', () {
        var raw = '[core "dUmMy1!@#"] dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy', subsection: 'dUmMy1!@#'), true);
      });

      test('When_VarHasDeprecatedSubsection_Should_BelongToSubsection', () {
        var raw = '[core.dummy] dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy', subsection: 'dummy'), true);
      });

      // Variable name related tests
      test('When_VarNameNotAlphaNumericDash_Should_ThrowException', () {
        var raw = '[core] dummy.';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_VarNameStartsWithDash_Should_ThrowException', () {
        var raw = '[core] -dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_VarNameAlphaNumericDash_Should_NotThrowException', () {
        var raw = '[core] dummy1-';
        var bytes = Uint8List.fromList(raw.codeUnits);
        GitConfig.fromBytes(bytes);
      });

      test('When_VarNameHasUppercase_Should_ConvertToLowercase', () {
        var raw = '[core] dUmMy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy'), true);
      });

      test('When_VarNameFollowedByComment_Should_ThrowException', () {
        var raw = '[core] dummy ;comment';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));

        raw = '[core] dummy #comment';
        bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });
    });

    group('Test config value', () {
      test('When_ValueIsMissing_Should_ReturnNull', () {
        var raw = '[core] dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.containsKey('core', 'dummy'), true);
        expect(config.getValue('core', 'dummy'), null);
      });

      test('When_ValueHasTrailingSpace_Should_TrimSpace', () {
        var raw = '[core] dummy = dummy\t ';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');
      });

      test('When_ValueHasValidEscapeChars_Should_FormatValue', () {
        var raw = r'[core] dummy = \ta\b\n\\\"';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, '\t\n\\"');
      });

      test('When_ValueHasEscapeNewlineChar_Should_AppendNextLine', () {
        var raw = '[core] dummy = du\\\nmm\\\ny';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');
      });

      test('When_ValueHasEscapeNothingChar_Should_IgnoreEscapeChar', () {
        var raw = r'[core] dummy = dummy\';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');
      });

      test('When_ValueStartsWithBackspaceChar_Should_IgnoreBackspaceChar', () {
        var raw = r'[core] dummy = \bdummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');
      });

      test('When_ValueHasOpenDQuote_Should_ThrowException', () {
        var raw = '[core] dummy = "dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        expect(() => GitConfig.fromBytes(bytes), throwsA(TypeMatcher<BadConfigLineException>()));
      });

      test('When_ValueInClosedDQuote_Should_EscapeCommentChars', () {
        var raw = r'[core] dummy = "#d;ummy"#';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, '#d;ummy');
      });

      test('When_ValueInClosedDQuote_Should_IncludeSpace', () {
        var raw = '[core] dummy = "dumm\ty "\t';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dumm\ty ');
      });

      test('When_ValueFollowedByComment_Should_IgnoreCommentAndTrailingSpace', () {
        var raw = '[core] dummy = dummy\t #dummy';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');

        raw = '[core] dummy = dummy\t ;dummy';
        bytes = Uint8List.fromList(raw.codeUnits);
        config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dummy');
      });

      test('When_ValueContainsWhitespace_Should_ReplaceWithRegularSpace', () {
        var raw = '[core] dummy = dum\tm y';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, 'dum m y');
      });

      test('When_VarHasMultipleValues_Should_ReturnAllValues', () {
        var raw = '[core] dummy = dummy1 \n dummy = dummy2 \n dummy = dummy3';
        var bytes = Uint8List.fromList(raw.codeUnits);
        var config = GitConfig.fromBytes(bytes);
        var values = config.getAllValues<GitConfigValueString>('core', 'dummy')!;
        expect(values.length, 3);
        expect(values[0]!.value, 'dummy1');
        expect(values[1]!.value, 'dummy2');
        expect(values[2]!.value, 'dummy3');
        // getValue should return the last value
        expect(config.getValue<GitConfigValueString>('core', 'dummy')!.value, values.last!.value);
      });
    });
  });

  group('Test git config [write]', () {
    test('When_ValueHasCommentChars_Should_SurroundWithDQuote', () {
      var config = GitConfig();
      config.setValue('core', 'dummy1', 'd#ummy');
      config.setValue('core', 'dummy2', 'd;ummy');
      var lines = String.fromCharCodes(config.serialize()).split('\n');
      expect(lines[0], '[core]');
      expect(lines[1].trim(), 'dummy1 = "d#ummy"');
      expect(lines[2].trim(), 'dummy2 = "d;ummy"');
    });

    test('When_ValueStartsOrEndsWithSpace_Should_SurroundWithDQuote', () {
      var config = GitConfig();
      config.setValue('core', 'dummy1', ' dummy');
      config.setValue('core', 'dummy2', 'dummy ');
      var lines = String.fromCharCodes(config.serialize()).split('\n');
      expect(lines[0], '[core]');
      expect(lines[1].trim(), 'dummy1 = " dummy"');
      expect(lines[2].trim(), 'dummy2 = "dummy "');
    });

    test('When_ValueContainsSpecialChars_Should_EscapeChars', () {
      var config = GitConfig();
      config.setValue('core', 'dummy', '\t\n"\\');
      var lines = String.fromCharCodes(config.serialize()).split('\n');
      expect(lines[0], '[core]');
      expect(lines[1].trim(), r'dummy = \t\n\"\\');
    });

    test('When_ValueIsNull_Should_OnlyWriteVarName', () {
      var config = GitConfig();
      config.setValue('core', 'dummy', null);
      var lines = String.fromCharCodes(config.serialize()).split('\n');
      expect(lines[0], '[core]');
      expect(lines[1].trim(), 'dummy');
    });
  });
}
