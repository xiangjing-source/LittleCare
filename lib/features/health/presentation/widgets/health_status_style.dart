import 'package:flutter/material.dart';

import '../../domain/health_models.dart';

Color healthLevelColor(HealthLevel level) => switch (level) {
  HealthLevel.normal => const Color(0xFF3F7D65),
  HealthLevel.elevated => const Color(0xFFB77820),
  HealthLevel.risk => const Color(0xFFB34646),
};
