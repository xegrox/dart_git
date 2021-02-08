import 'package:dart_git/src/plumbing/objects/blob.dart';
import 'package:test/test.dart';
import 'constants.dart' as c;
import 'utils.dart';

void main() {
  test('Test hashing of git objects', () {
    // Special characters
    var hash = (GitBlob.fromContent(fixture('blob_1.txt').readAsBytesSync())).hash.toString();
    expect(hash, c.hashes['blob_1.txt']);
    // No special characters
    var hash1 = (GitBlob.fromContent(fixture('blob_2.txt').readAsBytesSync())).hash.toString();
    expect(hash1, c.hashes['blob_2.txt']);
    // Empty file
    var hash2 = (GitBlob.fromContent(fixture('blob_3.txt').readAsBytesSync())).hash.toString();
    expect(hash2, c.hashes['blob_3.txt']);
  });
}