class GitException implements Exception {}

class PathSpecOutsideRepoException implements GitException {
  final String repoPath;
  final String pathSpec;
  PathSpecOutsideRepoException(this.repoPath, this.pathSpec);

  @override
  String toString() => "fatal: '$pathSpec' is outside repository at $repoPath";
}

class InvalidGitRepositoryException implements GitException {
  final String repoPath;
  InvalidGitRepositoryException(this.repoPath);
  @override
  String toString() => 'fatal: $repoPath is not a git repository';
}

class GitIndexException implements GitException {
  final String message;
  GitIndexException(this.message);
  @override
  String toString() => 'fatal: GitIndexError: $message';
}