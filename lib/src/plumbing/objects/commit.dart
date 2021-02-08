import 'dart:convert';
import 'dart:typed_data';
import 'object.dart';
import 'tree.dart';
import 'package:dart_git/src/git_config.dart';

class GitCommit extends GitObject {
  GitCommit.fromContent(Uint8List data) : super.fromContent(data);

  factory GitCommit.fromTree(GitTree tree, String message, GitConfig config) {
    List<int> data = [];

    var treeStr = '${tree.signature} ${tree.hash}\n';
    data.addAll(ascii.encode(treeStr));

    var section = config.getSection('user');
    var userStr = '${section.getRaw('name')} <${section.getRaw('email')}>';
    var time = DateTime.now();
    var secondsSinceEpoch = time.millisecondsSinceEpoch ~/ 1000;

    var timezoneOffset = time.timeZoneOffset.abs();
    var timezoneSign = time.timeZoneOffset.isNegative ? '-' : '+';
    var timezoneHours = timezoneOffset.inHours.toString().padLeft(2, '0');
    var timezoneMinutes = (timezoneOffset.inMinutes % 60).toString().padLeft(2, '0');
    var timezoneStr = timezoneSign + timezoneHours + timezoneMinutes;

    data.addAll(ascii.encode('author $userStr $secondsSinceEpoch $timezoneStr\n'));
    data.addAll(ascii.encode('committer $userStr $secondsSinceEpoch $timezoneStr\n'));
    data.addAll(ascii.encode('\n'));
    data.addAll(ascii.encode(message + '\n'));

    return GitCommit.fromContent(Uint8List.fromList(data));
  }

  @override
  String get signature => 'commit';

}