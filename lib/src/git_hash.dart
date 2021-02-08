import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';

class GitHash {

  Uint8List bytes;
  var _hexCodec = HexCodec();

  GitHash.fromBytes(Uint8List bytes) {
    if (bytes.length != 20) throw Exception("Invalid hash size");
    this.bytes = bytes;
  }
  
  GitHash(String hash) {
    if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) throw Exception("Invalid hash");
    bytes = _hexCodec.decode(hash);
  }

  GitHash.compute(Uint8List data) {
    this.bytes = sha1.convert(data).bytes;
  }

  @override
  String toString() => _hexCodec.encode(bytes);

}