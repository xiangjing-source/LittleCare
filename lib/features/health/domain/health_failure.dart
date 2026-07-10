class HealthFailure implements Exception {
  const HealthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
