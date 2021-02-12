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

  InvalidGitRepositoryException(this.repoPath) : super('fatal: $repoPath is not a git repository');
}

class GitIndexException extends GitException {
  final String msg;

  GitIndexException(this.msg) : super('fatal: GitIndexError: $msg');
}

class BadConfigLineException extends GitException {
  final int line;

  BadConfigLineException(this.line) : super('fatal: bad config line $line');
}

class BadNumericConfigValueException extends GitException {
  final String name;
  final String value;

  BadNumericConfigValueException(this.name, this.value)
      : super('fatal: bad numeric config value \'$value\' for \'$name\': invalid unit');
}

class GitCommitEmptyIdentityException extends GitException {
  GitCommitEmptyIdentityException() : super('fatal: author identity unknown');
}

class InvalidGitReferenceException extends GitException {
  final String ref;

  InvalidGitReferenceException(this.ref) : super('fatal: invalid git reference \'ref: $ref\'');
}

class BrokenReferenceException extends GitException {
  final String ref;

  BrokenReferenceException(this.ref) : super('fatal: broken git reference \'ref: $ref\'');
}

class CorruptObjectException extends GitException {
  final String objectName;
  final String hash;

  CorruptObjectException(this.objectName, this.hash) : super('fatal: $objectName object \'$hash\' is corrupt');
}

class NothingToCommitException extends GitException {
  NothingToCommitException() : super('fatal: nothing to commit, working tree clean or modified files untracked');
}
