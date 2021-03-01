import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:dart_git/src/exceptions.dart';

class GitClone {
  final Directory dir;
  final Uri uri;

  GitClone(this.dir, this.uri);

  Future<void> start() async {
    var endpointUri = uri.replace(path: uri.path + '/info/refs');
    var getUri = endpointUri.replace(query: 'service=git-upload-pack');
    var get = await http.get(getUri);
    if (get.statusCode == 200) {
      print(get.body);
    } else {
      throw GitException;
    }
  }
}
