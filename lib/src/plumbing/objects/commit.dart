import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

class GitCommitTimestamp extends Equatable {
  final int secondsSinceEpoch;
  final String timezone;

  GitCommitTimestamp({@required this.secondsSinceEpoch, @required this.timezone}) {
    var exception = GitException('incorrect timezone format');
    if (!['+', '-'].contains(timezone[0]) || timezone.length != 5 || int.tryParse(timezone) == null) throw exception;
  }

  factory GitCommitTimestamp.fromDateTime(DateTime time) {
    var secondsSinceEpoch = time.millisecondsSinceEpoch ~/ 1000;
    var timezoneOffset = time.timeZoneOffset.abs();
    var timezoneSign = time.timeZoneOffset.isNegative ? '-' : '+';
    var timezoneHours = timezoneOffset.inHours.toString().padLeft(2, '0');
    var timezoneMinutes = (timezoneOffset.inMinutes % 60).toString().padLeft(2, '0');
    var timezone = timezoneSign + timezoneHours + timezoneMinutes;
    return GitCommitTimestamp(secondsSinceEpoch: secondsSinceEpoch, timezone: timezone);
  }

  @override
  List<Object> get props => [secondsSinceEpoch, timezone];
}

class GitCommitUser extends Equatable {
  final String name;
  final String email;
  final GitCommitTimestamp timestamp;

  GitCommitUser({@required this.name, @required this.email, @required this.timestamp});

  String serialize() => '$name <$email> ${timestamp.secondsSinceEpoch} ${timestamp.timezone}';

  @override
  List<Object> get props => [name, email, timestamp];
}

class GitCommit extends GitObject with EquatableMixin {
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
      var separatorIndex = lines.indexOf(''); // index of empty line separating commit info and message
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
            if (identifier == 'committer') committer = user;
            break;
        }
      });
      if ([treeHash, author, committer].contains(null)) throw Exception;
      message = lines.sublist(separatorIndex + 1).join('\n');
    } catch (e) {
      throw GitException('invalid commit object format');
    }
  }

  GitCommit.fromTree(GitTree tree, this.message, GitConfig config, {this.parentHash}) {
    treeHash = tree.hash;
    var section = config.getSection('user');
    var name = section.getRaw('name') as String;
    var email = section.getRaw('email') as String;
    var timestamp = GitCommitTimestamp.fromDateTime(DateTime.now());
    var user = GitCommitUser(name: name, email: email, timestamp: timestamp);
    author = user;
    committer = user;
  }

  @override
  Uint8List serializeContent() {
    var lines = <String>[];
    lines.add('tree $treeHash');
    if (parentHash != null) lines.add('parent $parentHash');
    lines.add('author ${author.serialize()}');
    lines.add('committer ${committer.serialize()}');
    lines.add('');
    lines.add(message);
    return ascii.encode(lines.join('\n') + '\n');
  }

  @override
  String get signature => 'commit';

  @override
  List<Object> get props => [treeHash, parentHash, author, committer, message];
}
