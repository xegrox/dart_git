import 'package:test/test.dart';

import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/pack_file.dart';
import 'package:dart_git/src/plumbing/pack_file_idx.dart';
import 'constants.dart';

abstract class objOffsets {
  static const commit_1 = 158;
  static const commit_2 = 12;
  static const blob_1 = 283;
  static const blob_2 = 6091;
  static const blob_3 = 292;
  static const tree_1 = 6214;
  static const tree_2 = 6111;
}

void main() {
  test('Test git pack index v2 [read]', () {
    var idxFile = fixture('pack_index_v2.idx');
    var idx = GitPackFileIdx.fromBytes(idxFile.readAsBytesSync());

    var ofs_commit_1 = idx.getOffset(TestObjHashes.commit_1);
    var ofs_commit_2 = idx.getOffset(TestObjHashes.commit_2);
    var ofs_blob_1 = idx.getOffset(TestObjHashes.blob_1);
    var ofs_blob_2 = idx.getOffset(TestObjHashes.blob_2);
    var ofs_blob_3 = idx.getOffset(TestObjHashes.blob_3);
    var ofs_tree_1 = idx.getOffset(TestObjHashes.tree_1);
    var ofs_tree_2 = idx.getOffset(TestObjHashes.tree_2);

    expect(ofs_commit_1, objOffsets.commit_1);
    expect(ofs_commit_2, objOffsets.commit_2);
    expect(ofs_blob_1, objOffsets.blob_1);
    expect(ofs_blob_2, objOffsets.blob_2);
    expect(ofs_blob_3, objOffsets.blob_3);
    expect(ofs_tree_1, objOffsets.tree_1);
    expect(ofs_tree_2, objOffsets.tree_2);
    expect(idx.packFileHash, GitHash('1a5b3984b890f9353f7b4082ec1d3d7b8d143ec1'));
  });

  test('Test git pack file v2 [read]', () {
    var packFile = fixture('pack_file_v2.pack');
    var pack = GitPackFile.fromBytes(packFile.readAsBytesSync());

    var commit_1 = pack.getObject(objOffsets.commit_1);
    var commit_2 = pack.getObject(objOffsets.commit_2);
    var blob_1 = pack.getObject(objOffsets.blob_1);
    var blob_2 = pack.getObject(objOffsets.blob_2);
    var blob_3 = pack.getObject(objOffsets.blob_3);
    var tree_1 = pack.getObject(objOffsets.tree_1);
    var tree_2 = pack.getObject(objOffsets.tree_2);

    expect(commit_1.hash, TestObjHashes.commit_1);
    expect(commit_2.hash, TestObjHashes.commit_2);
    expect(blob_1.hash, TestObjHashes.blob_1);
    expect(blob_2.hash, TestObjHashes.blob_2);
    expect(blob_3.hash, TestObjHashes.blob_3);
    expect(tree_1.hash, TestObjHashes.tree_1);
    expect(tree_2.hash, TestObjHashes.tree_2);
  });
}
