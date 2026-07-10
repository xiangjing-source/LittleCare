class GroupFailure implements Exception {
  const GroupFailure(this.message, {this.code = 'unknown'});

  final String message;
  final String code;

  @override
  String toString() => message;
}
