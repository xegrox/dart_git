class GitException implements Exception {
  final String message;
  GitException(this.message);

  @override
  String toString() => message;
}

class PathSpecOutsideRepoException extends GitException {
  final String repoPath;
  final String pathSpec;
  PathSpecOutsideRepoException(this.repoPath, this.pathSpec)
      : super("fatal: '$pathSpec' is outside repository at $repoPath");
}

class InvalidGitRepositoryException extends GitException {
  final String repoPath;
  InvalidGitRepositoryException(this.repoPath)
      : super('fatal: $repoPath is not a git repository');
}

class GitIndexException extends GitException {
  final String message;
  GitIndexException(this.message)
      : super('fatal: GitIndexError: $message');
}

class BadConfigLineException extends GitException {
  final int line;
  BadConfigLineException(this.line)
      : super('fatal: bad config line $line');
}

class BadNumericConfigValueException extends GitException {
  final String name;
  final String value;
  BadNumericConfigValueException(this.name, this.value)
      : super('fatal: bad numeric config value \'$value\' for \'$name\': invalid unit');
}

class GitCommitEmptyIdentityException extends GitException {
  GitCommitEmptyIdentityException()
      : super('fatal: author identity unknown');
}

class InvalidGitReferenceException extends GitException {
  final String ref;
  InvalidGitReferenceException(this.ref)
      : super('fatal: invalid git reference \'ref: $ref\'');
}

class BrokenReferenceException extends GitException {
  final String ref;
  BrokenReferenceException(this.ref)
      : super('fatal: broken git reference \'ref: $ref\'');
}