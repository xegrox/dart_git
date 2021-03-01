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
    if (!['+', '-'].contains(timezone[0]) || timezone.length != 5 || int.tryParse(timezone) == null) {
      GitObjectException('Invalid commit format; invalid timezone format \'$timezone\'');
    }
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

  @override
  String get signature => 'commit';

  GitCommit.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      throw GitObjectException('Invalid commit format; data is empty');
    }
    var lines = ascii.decode(data).split('\n');
    if (lines.last.isEmpty) lines.removeLast(); // Last line is empty because of trailing newline
    var separatorIndex = lines.indexOf(''); // index of empty line separating commit info and message
    if (separatorIndex == -1) {
      throw GitObjectException('Invalid commit format; missing newline between header and message');
    }

    String _trimEmail(String email) {
      if (!email.startsWith('<') || !email.endsWith('>')) {
        throw GitObjectException('Invalid commit format; $email missing angle brackets');
      }
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
          if (split.length != 4) {
            throw GitObjectException('Invalid commit format; invalid user format \'$value\'');
          }
          var name = split[0];
          var email = _trimEmail(split[1]);
          var timestamp = GitCommitTimestamp(secondsSinceEpoch: int.parse(split[2]), timezone: split[3]);
          var user = GitCommitUser(name: name, email: email, timestamp: timestamp);
          if (identifier == 'author') author = user;
          if (identifier == 'committer') committer = user;
          break;
        default:
          throw GitObjectException('Invalid line \'$line\'');
      }
    });
    if ([treeHash, author, committer].contains(null)) {
      throw GitObjectException('Invalid commit format; missing info for tree, author or committer');
    }
    message = lines.sublist(separatorIndex + 1).join('\n');
  }

  GitCommit.fromTree(GitTree tree, String message, GitConfig config, {this.parentHash}) {
    treeHash = tree.hash;
    var section = config.getSection('user');
    var name = section.getRaw('name') as String;
    var email = section.getRaw('email') as String;
    var timestamp = GitCommitTimestamp.fromDateTime(DateTime.now());
    var user = GitCommitUser(name: name, email: email, timestamp: timestamp);
    author = user;
    committer = user;
    this.message = (message.endsWith('\n')) ? message.substring(message.length - 1) : message;
  }

  @override
  Uint8List serializeContent() {
    var lines = <String>[];
    lines.add('tree $treeHash');
    if (parentHash != null) lines.add('parent $parentHash');
    lines.add('author ${author.serialize()}');
    lines.add('committer ${committer.serialize()}');
    lines.add('');
    if (message.isNotEmpty) lines.add(message);
    return ascii.encode(lines.join('\n') + '\n');
  }

  @override
  List<Object> get props => [treeHash, parentHash, author, committer, message];
}
