import 'dart:typed_data';

import 'package:buffer/buffer.dart';

extension ReadUntil on ByteDataReader {
  Uint8List readUntil(int r) {
    var l = <int>[];
    while (true) {
      var c = readUint8();
      if (c == r) {
        return Uint8List.fromList(l);
      }
      l.add(c);
    }
  }
}
