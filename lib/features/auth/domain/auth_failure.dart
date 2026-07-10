class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code = 'unknown'});

  final String code;
  final String message;

  @override
  String toString() => message;
}
