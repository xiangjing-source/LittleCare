String formatHealthNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String formatBloodPressure({
  required num systolic,
  required num diastolic,
  bool includeUnit = true,
}) {
  final text =
      '${formatHealthNumber(systolic)}/${formatHealthNumber(diastolic)}';
  return includeUnit ? '$text mmHg' : text;
}
