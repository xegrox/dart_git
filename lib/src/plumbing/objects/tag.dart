import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/plumbing/objects/object.dart';

class GitTag extends GitObject with EquatableMixin {
  @override
  String get signature => GitObjectSignature.tag;

  final GitHash objectHash;
  final String objectSignature;
  final String name;
  final GitUserTimestamp tagger;
  final String message;

  GitTag(this.objectHash, this.objectSignature, this.name, this.tagger, this.message);

  factory GitTag.fromBytes(Uint8List data) {
    var lines = ascii.decode(data).split('\n');

    void checkLineExists(int index) {
      var lineNum = index + 1;
      if (lines.length < lineNum) {
        throw CorruptObjectException('Not enough lines for tag object; missing line $lineNum');
      }
    }

    checkLineExists(0);
    var objectEntry = lines[0];
    var objectEntryName = 'object ';
    if (objectEntry.length != objectEntryName.length + 40 || !objectEntry.startsWith(objectEntryName)) {
      throw CorruptObjectException('Invalid object entry in tag object');
    }
    var objectHashStr = objectEntry.substring(objectEntryName.length);
    GitHash objectHash;
    try {
      objectHash = GitHash(objectHashStr);
    } catch (_) {
      throw CorruptObjectException('Invalid object hash \'$objectHashStr\' in tag object');
    }

    checkLineExists(1);
    var typeEntry = lines[1];
    var typeEntryName = 'type ';
    if (!typeEntry.startsWith(typeEntryName)) throw CorruptObjectException('Invalid type entry in tag object');
    var objectSignature = typeEntry.substring(typeEntryName.length);
    var signatures = [
      GitObjectSignature.commit,
      GitObjectSignature.tree,
      GitObjectSignature.blob,
      GitObjectSignature.tag
    ];
    if (!signatures.contains(objectSignature)) {
      throw CorruptObjectException('Invalid signature \'$objectSignature\' in tag object');
    }

    checkLineExists(2);
    var nameEntry = lines[2];
    var nameEntryName = 'tag ';
    if (!nameEntry.startsWith(nameEntryName)) throw CorruptObjectException('Invalid tag name entry in tag object');
    var name = nameEntry.substring(nameEntryName.length);

    checkLineExists(3);
    var taggerEntry = lines[3];
    var taggerEntryName = 'tagger ';
    if (!taggerEntry.startsWith(taggerEntryName)) throw CorruptObjectException('Invalid tagger entry in tag object');
    var taggerEntryContent = taggerEntry.substring(taggerEntryName.length);
    var tagger = GitUserTimestamp.fromBytes(ascii.encode(taggerEntryContent));

    // Message
    if (lines[4].isEmpty) lines.removeAt(4); // Skip newline separator
    if (lines.last.isEmpty) lines.removeLast(); // Remove trailing newline
    var message = lines.sublist(4, lines.length).join('\n');
    return GitTag(objectHash, objectSignature, name, tagger, message);
  }

  @override
  Uint8List serializeContent() {
    var lines = <String>[];
    lines.add('object $objectHash');
    lines.add('type $objectSignature');
    lines.add('tag $name');
    lines.add('tagger ${ascii.decode(tagger.serialize())}');
    lines.add('');
    if (message.isNotEmpty) lines.add(message);
    return ascii.encode(lines.join('\n') + '\n');
  }

  @override
  List<Object> get props => [];
}
