enum HealthLevel { normal, elevated, risk }

extension HealthLevelLabel on HealthLevel {
  String get label => switch (this) {
    HealthLevel.normal => '在常见范围内',
    HealthLevel.elevated => '比平时稍高',
    HealthLevel.risk => '建议稍后复测',
  };
}
