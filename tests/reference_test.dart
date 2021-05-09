import 'dart:typed_data';

import 'package:dart_git/src/git_hash.dart';
import 'package:test/test.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/plumbing/reference.dart';

void main() {
  group('Test reference name', () {
    var dummyHash = GitHash.compute(Uint8List(0));

    test('When_NameStartWithDot_Should_ThrowException', () {
      var refName = '.dummy';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameStartsWithSlash_Should_ThrowException', () {
      var refName = '/dummy';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameEndsWithDot_Should_ThrowException', () {
      var refName = 'dummy.';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameEndsWithSlash_Should_ThrowException', () {
      var refName = 'dummy/';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameEndsWithDotLock_Should_ThrowException', () {
      var refName = 'dummy.lock';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameIs@_Should_ThrowException', () {
      var refName = '@';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameHasInvalidChar_Should_ThrowException', () {
      // '@{' sequence
      var refName = 'd@{d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // two consecutive dots '..'
      refName = 'd..d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // multiple consecutive slashes
      refName = 'd//d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // ascii control chars
      refName = 'd\x00d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      refName = 'd\x19d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      refName = 'd\x7Fd';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // space
      refName = 'd d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // tilde
      refName = 'd~d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // caret
      refName = 'd^d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // colon
      refName = 'd:d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // question mark
      refName = 'd?d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // asterisk
      refName = 'd*d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // open square bracket
      refName = 'd[d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
      // backslash
      refName = r'd\d';
      expect(() => GitReferenceHash(refName, dummyHash), throwsA(TypeMatcher<InvalidReferenceNameException>()));
    });

    test('When_NameIsValid_ShouldNotThrowException', () {
      var refName = 'd.lock@mmy/du]m/Y\x80';
      GitReferenceHash(refName, dummyHash);
    });
  });
}
