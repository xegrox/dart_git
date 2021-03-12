class GitException implements Exception {
  final String message;

  GitException(this.message);

  @override
  String toString() => message;
}

class PathSpecOutsideRepoException extends GitException {
  PathSpecOutsideRepoException(String repoPath, String pathSpec)
      : super('fatal: \'$pathSpec\' is outside repository at $repoPath');
}

class PathSpecNoMatchException extends GitException {
  PathSpecNoMatchException(String pathSpec) : super('fatal: pathspec \'$pathSpec\' did not match any files');
}

class InvalidGitRepositoryException extends GitException {
  InvalidGitRepositoryException(String repoPath) : super('fatal: $repoPath is not a git repository');
}

class GitIndexException extends GitException {
  GitIndexException(String msg) : super('fatal: index corrupted: $msg');
}

class GitPackFileException extends GitException {
  GitPackFileException(String msg) : super('fatal: pack file error: $msg');
}

class GitPackIdxFileException extends GitException {
  final String msg;

  GitPackIdxFileException(this.msg) : super('fatal: pack index file error: $msg');
}

class BadConfigLineException extends GitException {
  BadConfigLineException(int line) : super('fatal: bad config line $line');
}

class BadNumericConfigValueException extends GitException {
  BadNumericConfigValueException(String name, String value)
      : super('fatal: bad numeric config value \'$value\' for \'$name\': invalid unit');
}

class GitCommitCredentialsException extends GitException {
  GitCommitCredentialsException() : super('fatal: author credentials missing from config');
}

class InvalidGitReferenceException extends GitException {
  InvalidGitReferenceException(String ref) : super('fatal: invalid git reference \'ref: $ref\'');
}

class BrokenReferenceException extends GitException {
  BrokenReferenceException(String ref) : super('fatal: broken git reference \'ref: $ref\'');
}

class GitObjectException extends GitException {
  GitObjectException(String msg) : super('fatal: corrupt object: $msg');
}

class NothingToCommitException extends GitException {
  NothingToCommitException() : super('fatal: nothing to commit, working tree clean or modified files untracked');
}

class GitDeltaException extends GitException {
  GitDeltaException(String msg) : super('fatal: error resolving delta: $msg');
}
