class GitException implements Exception {
  final String message;

  GitException(this.message);

  @override
  String toString() => message;
}

// PathSpec
class PathSpecOutsideRepoException extends GitException {
  PathSpecOutsideRepoException(String repoPath, String pathSpec)
      : super('fatal: \'$pathSpec\' is outside repository at $repoPath');
}

class PathSpecNoMatchException extends GitException {
  PathSpecNoMatchException(String pathSpec) : super('fatal: pathspec \'$pathSpec\' did not match any files');
}

// Repo
class InvalidGitRepositoryException extends GitException {
  InvalidGitRepositoryException(String repoPath) : super('fatal: $repoPath is not a git repository');
}

// Index
class GitIndexException extends GitException {
  GitIndexException(String msg) : super('fatal: index corrupted: $msg');
}

// Pack file
class GitPackFileException extends GitException {
  GitPackFileException(String msg) : super('fatal: pack file error: $msg');
}

class GitPackIdxFileException extends GitException {
  GitPackIdxFileException(String msg) : super('fatal: pack index file error: $msg');
}

// Config
class BadConfigLineException extends GitException {
  BadConfigLineException(int line) : super('fatal: bad config line $line');
}

class BadNumericConfigValueException extends GitException {
  BadNumericConfigValueException(String name, String value)
      : super('fatal: bad numeric config value \'$value\' for \'$name\': invalid unit');
}

// Commit
class MissingCredentialsException extends GitException {
  MissingCredentialsException() : super('fatal: author credentials missing from config');
}

class NothingToCommitException extends GitException {
  NothingToCommitException() : super('fatal: nothing to commit');
}

// Ref
class BrokenReferenceException extends GitException {
  BrokenReferenceException(String pathSpec) : super('fatal: broken git reference \'ref: $pathSpec\'');
}

// Object
class CorruptObjectException extends GitException {
  final String msg;
  CorruptObjectException(this.msg) : super('fatal: corrupt object: $msg');
}

// Tag
class InvalidTagNameException extends GitException {
  InvalidTagNameException(String name) : super('fatal: invalid tag name \'$name\'');
}
