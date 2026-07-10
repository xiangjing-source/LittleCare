import '../domain/health_level.dart';

abstract final class HealthStatusService {
  static HealthLevel bloodPressure(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) return HealthLevel.normal;
    if (systolic < 140 && diastolic < 90) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel fastingSugar(double value) {
    if (value >= 3.9 && value <= 6.1) return HealthLevel.normal;
    if (value > 6.1 && value < 7.0) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel postprandialSugar(double value) {
    if (value >= 3.9 && value <= 7.8) return HealthLevel.normal;
    if (value > 7.8 && value < 11.1) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel totalCholesterol(double value) {
    if (value >= 3.0 && value <= 5.2) return HealthLevel.normal;
    if (value > 5.2 && value < 6.2) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel triglycerides(double value) {
    if (value <= 1.7) return HealthLevel.normal;
    if (value < 2.3) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel ldl(double value) {
    if (value <= 3.4) return HealthLevel.normal;
    if (value < 4.1) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel hdl(double value) {
    if (value >= 1.0) return HealthLevel.normal;
    if (value >= 0.8) return HealthLevel.elevated;
    return HealthLevel.risk;
  }

  static HealthLevel overall(Iterable<HealthLevel?> values) {
    final levels = values.whereType<HealthLevel>().toList();
    if (levels.contains(HealthLevel.risk)) return HealthLevel.risk;
    if (levels.contains(HealthLevel.elevated)) return HealthLevel.elevated;
    return HealthLevel.normal;
  }

  static String guidance(HealthLevel level) => switch (level) {
    HealthLevel.normal => '这次记录在常见参考范围内。',
    HealthLevel.elevated => '这次记录比常见参考范围稍高，可以稍后再测一次。',
    HealthLevel.risk => '建议稍后复测；如果持续变化明显或感到不适，可以咨询专业人员。',
  };
}
