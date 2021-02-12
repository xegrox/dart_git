import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';

abstract class GitObject {
  GitObject();

  String get signature;

  Uint8List serializeContent();

  @protected
  Uint8List getContent(Uint8List data) {
    try {
      var sig = ascii.decode(data.sublist(0, ascii.encode(signature).length));
      if (sig != signature) throw Exception;
      var cLengthEndIndex = data.indexOf(0x00, sig.length);
      var cLengthBytes = data.sublist(sig.length, cLengthEndIndex);
      var contentLength = int.parse(ascii.decode(cLengthBytes));
      var content = data.sublist(cLengthEndIndex + 1);
      if (content.length != contentLength) throw Exception;
      return data.sublist(cLengthEndIndex + 1);
    } catch (e) {
      throw GitException('invalid object format');
    }
  }

  Uint8List serialize() {
    var content = serializeContent();
    var serializedData = <int>[];
    var contentLength = content.lengthInBytes;
    serializedData.addAll(utf8.encode('$signature $contentLength'));
    serializedData.add(0x00);
    serializedData.addAll(content);
    return Uint8List.fromList(serializedData);
  }

  GitHash get hash => GitHash.compute(serialize());
}
