import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:test/test.dart';
import 'constants.dart' as c;
import 'utils.dart';

void main() {
  test('Test hashing of git objects', () async {
    // Special characters
    var hash = (await GitBlob.fromBytes(fixture('blob_1.txt').readAsBytesSync())).hash.toString();
    expect(hash, c.hashes['blob_1.txt']);
    // No special characters
    var hash1 = (await GitBlob.fromBytes(fixture('blob_2.txt').readAsBytesSync())).hash.toString();
    expect(hash1, c.hashes['blob_2.txt']);
    // Empty file
    var hash2 = (await GitBlob.fromBytes(fixture('blob_3.txt').readAsBytesSync())).hash.toString();
    expect(hash2, c.hashes['blob_3.txt']);
  });
}