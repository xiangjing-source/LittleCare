class PhoneNumberValidator {
  const PhoneNumberValidator._();

  static final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp _mainlandChinaPattern = RegExp(r'^1\d{10}$');

  static String normalize(String input) {
    final compact = input.replaceAll(RegExp(r'[\s()-]'), '');
    if (_mainlandChinaPattern.hasMatch(compact)) {
      return '+86$compact';
    }
    return compact;
  }

  static String? validate(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) {
      return '请输入手机号';
    }
    if (!_e164Pattern.hasMatch(normalized)) {
      return '请输入有效手机号，例如 13800138000';
    }
    return null;
  }
}

class SmsCodeValidator {
  const SmsCodeValidator._();

  static final RegExp _pattern = RegExp(r'^\d{6}$');

  static String? validate(String input) {
    if (input.isEmpty) {
      return '请输入验证码';
    }
    if (!_pattern.hasMatch(input)) {
      return '验证码应为 6 位数字';
    }
    return null;
  }
}
