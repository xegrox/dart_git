import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';
import 'package:meta/meta.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_git/src/git_config.dart';
import 'object.dart';

class GitCommitTimestamp {
  final int secondsSinceEpoch;
  final String timezone;
  
  GitCommitTimestamp({
    @required this.secondsSinceEpoch,
    @required this.timezone
  }) {
    var exception = GitException('incorrect timezone format');
    if (
      !['+', '-'].contains(timezone[0]) ||
      timezone.length != 5 ||
      int.tryParse(timezone) == null
    ) throw exception;
  }
  
  factory GitCommitTimestamp.fromDateTime(DateTime time) {
    var secondsSinceEpoch = time.millisecondsSinceEpoch ~/ 1000;
    var timezoneOffset = time.timeZoneOffset.abs();
    var timezoneSign = time.timeZoneOffset.isNegative ? '-' : '+';
    var timezoneHours = timezoneOffset.inHours.toString().padLeft(2, '0');
    var timezoneMinutes = (timezoneOffset.inMinutes % 60).toString().padLeft(2, '0');
    var timezone = timezoneSign + timezoneHours + timezoneMinutes;
    return GitCommitTimestamp(
      secondsSinceEpoch: secondsSinceEpoch, 
      timezone: timezone
    );
  }
}

class GitCommitUser {
  final String name;
  final String email;
  final GitCommitTimestamp timestamp;

  GitCommitUser({
    @required this.name,
    @required this.email,
    @required this.timestamp
  });

  String serialize() => '$name <$email> ${timestamp.secondsSinceEpoch} ${timestamp.timezone}';
}

class GitCommit extends GitObject {

  DateTime time = DateTime.now();
  GitHash treeHash;
  GitHash parentHash;
  GitCommitUser author;
  GitCommitUser committer;
  String message;

  GitCommit.fromBytes(Uint8List data) {
    var content = super.getContent(data);
    try {
      var lines = ascii.decode(content).split('\n');
      var separatorIndex = lines.indexOf(''); // empty line separating commit info and message
      if (separatorIndex == -1) throw Exception;

      String _trimEmail(String email) {
        if (!email.startsWith('<') || !email.endsWith('>')) throw Exception;
        return email.substring(1, email.length - 1);
      }

      var header = lines.sublist(0, separatorIndex);
      header.forEach((line) {
        var identifier = line.substring(0, line.indexOf(' '));
        var value = line.substring(line.indexOf(' ') + 1, line.length);
        switch (identifier) {
          case 'tree':
            treeHash = GitHash(value);
            break;
          case 'parent':
            parentHash = GitHash(value);
            break;
          case 'author':
          case 'committer':
            var split = value.split(' ');
            var name = split[0];
            var email = _trimEmail(split[1]);
            var timestamp = GitCommitTimestamp(secondsSinceEpoch: int.parse(split[2]), timezone: split[3]);
            var user = GitCommitUser(name: name, email: email, timestamp: timestamp);
            if (identifier == 'author') author = user;
            else if (identifier == 'committer') committer = user;
            break;
        }
      });
      if ([treeHash, author, committer].contains(null)) throw Exception;
      message = lines.sublist(separatorIndex + 1).join('\n');
    } catch (e) {
      throw GitException('invalid commit object format');
    }
  }

  GitCommit.fromTree(GitTree tree, String this.message, GitConfig config, {GitHash this.parentHash}) {
    this.treeHash = tree.hash;
    var timestamp = GitCommitTimestamp.fromDateTime(DateTime.now());
    var section = config.getSection('user');
    var user = GitCommitUser(
      name: section.getRaw('name'),
      email: section.getRaw('email'),
      timestamp: timestamp
    );
    this.author = user;
    this.committer = user;
  }

  @override
  Uint8List serializeContent() {
    var lines = <String>[];
    lines.add('tree ${this.treeHash}');
    if (this.parentHash != null) lines.add('parent ${this.parentHash}');
    lines.add('author ${this.author.serialize()}');
    lines.add('committer ${this.committer.serialize()}');
    lines.add('');
    lines.add(message);
    return ascii.encode(lines.join('\n') + '\n');
  }

  @override
  String get signature => 'commit';

}