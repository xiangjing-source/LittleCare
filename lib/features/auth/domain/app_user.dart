class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.recoveryCode,
    this.phoneNumber,
  });

  final String id;
  final String displayName;
  final String? recoveryCode;
  final String? phoneNumber;
}
