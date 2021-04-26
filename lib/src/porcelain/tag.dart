import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tag.dart';
import 'package:dart_git/src/plumbing/reference.dart';

extension Tag on GitRepo {
  void writeTag(String name, GitHash objectHash, [String message = '']) {
    var object = readObject(objectHash);

    var refHash = objectHash;
    // Write annotated tag object
    if (message.isNotEmpty) {
      var config = readConfig();
      var username = config.getValue<GitConfigValueString>('user', 'name');
      var email = config.getValue<GitConfigValueString>('user', 'email');
      if (username == null || email == null) throw MissingCredentialsException();
      var time = DateTime.now();
      var tagger = GitUserTimestamp(username.value, email.value, time, time.timeZoneOffset);
      var tagObj = GitTag(objectHash, object.signature, name, tagger, message);
      writeObject(tagObj);
      refHash = tagObj.hash;
    }

    GitReferenceHash ref;
    try {
      ref = GitReferenceHash('refs/tags/$name', refHash);
    } on GitException {
      throw InvalidTagNameException(name);
    }
    writeReference(ref);
  }

  bool deleteTag(String name) => deleteReference('refs/tags/$name');
}
