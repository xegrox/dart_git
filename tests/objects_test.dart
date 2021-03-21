import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:dart_git/src/plumbing/objects/commit.dart';
import 'package:dart_git/src/plumbing/objects/tag.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'constants.dart';

Uint8List stripHeader(Uint8List data) => data.sublist(data.indexOf(0x00) + 1);

Uint8List zlibDecode(Uint8List data) => Uint8List.fromList(zlib.decode(data));

void main() {
  test('Test parse blob object', () {
    final blob_content_1 = zlibDecode(TestObjFiles.blob_1.readAsBytesSync());
    final blob_content_2 = zlibDecode(TestObjFiles.blob_2.readAsBytesSync());
    final blob_content_3 = zlibDecode(TestObjFiles.blob_3.readAsBytesSync());

    final blob_1 = GitBlob.fromBytes(stripHeader(blob_content_1));
    final blob_2 = GitBlob.fromBytes(stripHeader(blob_content_2));
    final blob_3 = GitBlob.fromBytes(stripHeader(blob_content_3));

    expect(blob_1.hash, TestObjHashes.blob_1);
    expect(blob_2.hash, TestObjHashes.blob_2);
    expect(blob_3.hash, TestObjHashes.blob_3);
  });

  test('Test parse tree object', () {
    final tree_content_1 = zlibDecode(TestObjFiles.tree_1.readAsBytesSync());
    final tree_content_2 = zlibDecode(TestObjFiles.tree_2.readAsBytesSync());

    final tree_1 = GitTree.fromBytes(stripHeader(tree_content_1));
    final tree_2 = GitTree.fromBytes(stripHeader(tree_content_2));

    expect(tree_1.hash, TestObjHashes.tree_1);
    expect(tree_2.hash, TestObjHashes.tree_2);
  });

  test('Test parse commit object', () {
    final commit_content_1 = zlibDecode(TestObjFiles.commit_1.readAsBytesSync());
    final commit_content_2 = zlibDecode(TestObjFiles.commit_2.readAsBytesSync());

    final commit_1 = GitCommit.fromBytes(stripHeader(commit_content_1));
    final commit_2 = GitCommit.fromBytes(stripHeader(commit_content_2));

    expect(commit_1.hash, TestObjHashes.commit_1);
    expect(commit_2.hash, TestObjHashes.commit_2);
  });

  test('Test parse tag object', () {
    final tag_content_1 = zlibDecode(TestObjFiles.tag_1.readAsBytesSync());
    final tag_content_2 = zlibDecode(TestObjFiles.tag_2.readAsBytesSync());

    final tag_1 = GitTag.fromBytes(stripHeader(tag_content_1));
    final tag_2 = GitTag.fromBytes(stripHeader(tag_content_2));

    expect(tag_1.hash, TestObjHashes.tag_1);
    expect(tag_2.hash, TestObjHashes.tag_2);
  });
}
