import 'dart:convert';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/utils.dart';

abstract class GitObjectSignature {
  static const commit = 'commit';
  static const tree = 'tree';
  static const blob = 'blob';
  static const tag = 'tag';
}

abstract class GitObject {
  GitObject();

  String get signature;

  Uint8List serializeContent();

  Uint8List serialize() {
    var serializedData = <int>[];
    var content = serializeContent();
    serializedData.addAll(ascii.encode('$signature ${content.length}'));
    serializedData.add(0x00);
    serializedData.addAll(content);
    return Uint8List.fromList(serializedData);
  }

  GitHash get hash => GitHash.compute(serialize());
}

class GitUserTimestamp extends Equatable {
  final String userName;
  final String email;
  final DateTime time;
  final Duration timezone;

  GitUserTimestamp(this.userName, this.email, this.time, this.timezone) {
    if ((timezone.inHours).abs() >= 24) throw GitException('Invalid timezone');
  }

  factory GitUserTimestamp.fromBytes(Uint8List data) {
    var reader = ByteDataReader();
    reader.add(data);
    try {
      var userName = ascii.decode(reader.readUntil(0x20));
      var emailFmt = ascii.decode(reader.readUntil(0x20));
      if (!emailFmt.startsWith('<') || !emailFmt.endsWith('>')) throw Exception;
      var email = emailFmt.substring(1, emailFmt.length - 1);

      var secondsAfterEpoch = int.parse(ascii.decode(reader.readUntil(0x20)));
      if (secondsAfterEpoch.isNegative) throw Exception;
      var time = DateTime.fromMillisecondsSinceEpoch(secondsAfterEpoch * 1000, isUtc: true);

      var timezoneFmt = ascii.decode(reader.read(reader.remainingLength));
      if (timezoneFmt.length != 5 || !['+', '-'].contains(timezoneFmt[0])) throw Exception;
      var sign = timezoneFmt[0];
      var hours = int.parse(sign + timezoneFmt.substring(1, 3));
      if (hours.abs() >= 24) throw Exception;
      var minutes = int.parse(sign + timezoneFmt.substring(3, 5));
      var timezone = Duration(hours: hours, minutes: minutes);
      return GitUserTimestamp(userName, email, time, timezone);
    } catch (_) {
      throw CorruptObjectException('Invalid user timestamp format');
    }
  }

  Uint8List serialize() {
    var timezoneSign = timezone.isNegative ? '-' : '+';
    var timezoneMinutes = (timezone.inMinutes - timezone.inHours * 60).abs().toString().padLeft(2, '0');
    var timezoneHours = timezone.inHours.abs().toString().padLeft(2, '0');
    var timezoneFmt = timezoneSign + timezoneHours + timezoneMinutes;
    var secondsSinceEpoch = time.millisecondsSinceEpoch ~/ 1000;
    return ascii.encode('$userName <$email> $secondsSinceEpoch $timezoneFmt');
  }

  @override
  List<Object> get props => [userName, email, time, timezone];
}
