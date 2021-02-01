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
    if (hash.length != 20) throw Exception("Invalid hash size");
    bytes = _hexCodec.decode(hash);
  }

  GitHash.compute(Uint8List data) {
    this.bytes = sha1.convert(data).bytes;
  }

  @override
  String toString() => _hexCodec.encode(bytes);

}