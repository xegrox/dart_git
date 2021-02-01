import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_repo.dart';

extension Checkout on GitRepo {

  Future<void> checkout(String ref) async {
    validate();
    /**
    1. check GIT_DIR/$path
    2. check GIT_DIR/refs/$path
    3. check GIT_DIR/refs/{tags,heads,remotes}/$path
    4. check GIT_DIR/refs/remotes/$path/HEAD
    Possible $path: refs/tags/v1.0.0
    Reject if not in GIT_DIR
    If detached, write hash
    **/

    Future<void> write(String fullPath) async {
      // Check if ref is headless (compare hash to those in refs/{heads,tags,remotes}
      //if (fullPath.contains()
      //await RepoTree(this).headFile.writeAsString(s);
    }

    var fullPath = p.normalize(p.join(this.dir.path, ref));
    var refFile = File(fullPath);

    // Throw error if path is out of scope
    if (!p.isWithin(this.getGitDir().path, fullPath)) throw PathSpecOutsideRepoException(this.dir.path, ref);

    // check GIT_DIR/$path
    if (refFile.existsSync()) {

    }

  }

}