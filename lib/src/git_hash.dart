import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

Uint8List _hashToBytes(String hash) {
  var data = <int>[];
  for (var i = 0; i < 40; i += 2) {
    var intHex = hash.substring(i, i + 2);
    data.add(int.parse(intHex, radix: 16));
  }
  return Uint8List.fromList(data);
}

String _bytesToHash(Uint8List bytes) {
  var hash = '';
  bytes.forEach((byte) {
    hash += byte.toRadixString(16).padLeft(2, '0');
  });
  return hash;
}

class GitHash extends Equatable {
  final Uint8List bytes;

  GitHash.fromBytes(this.bytes) {
    if (bytes.length != 20) throw Exception('Invalid hash size');
  }

  factory GitHash(String hash) {
    if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) throw Exception('Invalid hash');
    return GitHash.fromBytes(_hashToBytes(hash));
  }

  factory GitHash.compute(Uint8List data) {
    var bytes = Uint8List.fromList(sha1.convert(data).bytes);
    return GitHash.fromBytes(bytes);
  }

  @override
  String toString() => _bytesToHash(bytes);

  @override
  List<Object> get props => [bytes];
}
