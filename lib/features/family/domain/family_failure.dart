class FamilyFailure implements Exception {
  const FamilyFailure(this.message, {this.code = 'unknown'});

  final String code;
  final String message;

  @override
  String toString() => message;
}
