import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_config.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';
import 'package:dart_git/src/plumbing/objects/tree.dart';

class GitCommit extends GitObject with EquatableMixin {
  final GitHash treeHash;
  final List<GitHash> parentHashes;
  final GitUserTimestamp author;
  final GitUserTimestamp committer;
  final String message;

  @override
  String get signature => GitObjectSignature.commit;

  GitCommit._(this.treeHash, this.parentHashes, this.author, this.committer, this.message);

  factory GitCommit.fromBytes(Uint8List data) {
    var lines = ascii.decode(data).split('\n');

    void checkLineExists(int index) {
      var lineNum = index + 1;
      if (lines.length < lineNum) {
        throw CorruptObjectException('Not enough lines for commit object; missing line $lineNum');
      }
    }

    // Tree entry
    checkLineExists(0);
    var treeEntry = lines[0];
    var treeEntryName = 'tree ';
    if (treeEntry.length != treeEntryName.length + 40 || !treeEntry.startsWith(treeEntryName)) {
      throw CorruptObjectException('Invalid tree entry in commit object');
    }
    var treeHashStr = treeEntry.substring(treeEntryName.length);
    GitHash treeHash;
    try {
      treeHash = GitHash(treeHashStr);
    } catch (_) {
      throw CorruptObjectException('Invalid tree hash \'$treeHashStr\' in commit object');
    }

    // Parent entry
    var parentEntryName = 'parent ';
    checkLineExists(1);
    var parentHashes = <GitHash>[];
    for (var i = 1; lines[i].startsWith(parentEntryName); i++) {
      var parentEntry = lines[i];
      if (parentEntry.length != parentEntryName.length + 40) {
        throw CorruptObjectException('Invalid parent entry in commit object');
      }
      var parentHashStr = parentEntry.substring(parentEntryName.length);
      try {
        parentHashes.add(GitHash(parentHashStr));
        checkLineExists(i + 1);
      } on GitException {
        throw CorruptObjectException('Invalid parent hash \'$parentHashStr\' in commit object');
      }
    }

    // Author entry
    var nextLineIndex = parentHashes.length + 1;
    checkLineExists(nextLineIndex);
    var authorEntry = lines[nextLineIndex];
    var authorEntryName = 'author ';
    if (!authorEntry.startsWith(authorEntryName)) {
      throw CorruptObjectException('Invalid author entry in commit object');
    }
    var authorEntryContent = authorEntry.substring(authorEntryName.length);
    var author = GitUserTimestamp.fromBytes(ascii.encode(authorEntryContent));
    nextLineIndex++;

    // Committer entry
    checkLineExists(nextLineIndex);
    var committerEntry = lines[nextLineIndex];
    var committerEntryName = 'committer ';
    if (!committerEntry.startsWith(committerEntryName)) {
      throw CorruptObjectException('Invalid author entry in commit object');
    }
    var committerEntryContent = committerEntry.substring(committerEntryName.length);
    var committer = GitUserTimestamp.fromBytes(ascii.encode(committerEntryContent));
    nextLineIndex++;

    // Message
    if (lines[nextLineIndex].isEmpty) nextLineIndex++; // Skip newline separator
    if (lines.last.isEmpty) lines.removeLast(); // Remove trailing newline
    var message = lines.sublist(nextLineIndex, lines.length).join('\n');
    return GitCommit._(treeHash, parentHashes, author, committer, message);
  }

  factory GitCommit.fromTree(GitTree tree, String message, GitConfig config, [List<GitHash> parentHashes = const []]) {
    var treeHash = tree.hash;
    var section = config.getSection('user');
    var name = section.getRaw('name') as String;
    var email = section.getRaw('email') as String;
    var currentTime = DateTime.now();
    var userTimestamp = GitUserTimestamp(name, email, currentTime, currentTime.timeZoneOffset);
    var author = userTimestamp;
    var committer = userTimestamp;
    return GitCommit._(treeHash, parentHashes, author, committer, message);
  }

  @override
  Uint8List serializeContent() {
    var lines = <String>[];
    lines.add('tree $treeHash');
    parentHashes.forEach((hash) {
      lines.add('parent $hash');
    });
    lines.add('author ${ascii.decode(author.serialize())}');
    lines.add('committer ${ascii.decode(committer.serialize())}');
    lines.add('');
    if (message.isNotEmpty) lines.add(message);
    return ascii.encode(lines.join('\n') + '\n');
  }

  @override
  List<Object> get props => [treeHash, parentHashes, author, committer, message];
}
