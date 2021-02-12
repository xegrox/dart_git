import 'dart:io';
import 'dart:typed_data';

import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:test/test.dart';

import 'constants.dart';
import 'utils.dart';

final decoder = ZLibDecoder().convert;

void main() {
  test('Test parse blob object', () {
    final blob_content_1 = decoder(objFixture('blob_1').readAsBytesSync());
    final blob_content_2 = decoder(objFixture('blob_2').readAsBytesSync());
    final blob_content_3 = decoder(objFixture('blob_3').readAsBytesSync());

    final blob_1 = GitBlob.fromBytes(Uint8List.fromList(blob_content_1));
    final blob_2 = GitBlob.fromBytes(Uint8List.fromList(blob_content_2));
    final blob_3 = GitBlob.fromBytes(Uint8List.fromList(blob_content_3));

    expect(blob_1.hash, hashes['blob_1.txt']);
    expect(blob_2.hash, hashes['blob_2.txt']);
    expect(blob_3.hash, hashes['blob_3.txt']);
  });

  test('Test parse tree object', () {
    final tree_content = decoder(objFixture('tree_1').readAsBytesSync());
    final tree = GitTree.fromBytes(Uint8List.fromList(tree_content));
    expect(tree.hash, GitHash('da185a97bc42838a541ec2793edc74d673d2a6fa'));
  });

  test('Test parse commit object', () {
    final commit_content = decoder(objFixture('commit_1').readAsBytesSync());
    final commit = GitCommit.fromBytes(Uint8List.fromList(commit_content));
    expect(commit.hash, GitHash('80597cc4cb567f0798f0f5e0330cc7d6d23dfa51'));
  });
}
