import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:dart_git/src/exceptions.dart';
import 'package:dart_git/src/git_hash.dart';
import 'package:dart_git/src/git_repo.dart';

const _symbolicRefPrefix = 'ref:';
const _refPrefix = 'refs/';
const _refHeadPrefix = _refPrefix + 'heads/';
const _refTagPrefix = _refPrefix + 'tags/';
const _refRemotePrefix = _refPrefix + 'remotes/';

enum GitReferenceType { hash, symbolic }

class GitReference {
  final GitReferenceType type;
  final GitRepo repo;
  final String _symbolicTarget;

  File resolveTargetFile() {
    if (type == GitReferenceType.hash) return repo.headFile;
    return File(p.joinAll([repo.getGitDir().path] + _symbolicTarget.split('/')));
  }

  bool isDetached() => (type == GitReferenceType.hash);
  GitHash _detachedHash;

  GitHash readHash() {
    if (type == GitReferenceType.hash) return _detachedHash;
    var targetFile = File(p.join(repo.getGitDir().path, _symbolicTarget));
    var hash = targetFile.readAsStringSync();
    try {
      return GitHash(hash);
    } catch (e) {
      throw BrokenReferenceException(_symbolicTarget);
    }
  }

  GitReference._(this.type, this.repo, this._symbolicTarget);

  GitReference.fromHash(this.repo, this._detachedHash)
      : _symbolicTarget = null,
        type = GitReferenceType.hash;

  factory GitReference.fromLink(GitRepo repo, String link) {
    var exception = InvalidGitReferenceException(link);
    link = link.trim();
    if (!link.startsWith(_symbolicRefPrefix)) throw exception;
    var target = link.substring(_symbolicRefPrefix.length).trim();
    if (!target.startsWith(_refPrefix)) throw exception;
    if (target == _refPrefix) throw exception;
    return GitReference._(GitReferenceType.symbolic, repo, target);
  }

  bool isHead() => _symbolicTarget.startsWith(_refHeadPrefix);

  bool isTag() => _symbolicTarget.startsWith(_refTagPrefix);

  bool isRemote() => _symbolicTarget.startsWith(_refRemotePrefix);
}
