import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_copy.dart';
import '../../../group/presentation/pages/group_home_page.dart';
import '../../domain/phone_number_validator.dart';
import '../providers/auth_providers.dart';
import '../state/phone_auth_state.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authUserProvider);
    return authUser.when(
      loading: () => const _LoadingPage(),
      error:
          (error, stackTrace) => _ConnectionErrorPage(
            onRetry: () => ref.invalidate(authUserProvider),
          ),
      data: (user) {
        if (user != null) return GroupHomePage(user: user);
        final state = ref.watch(phoneAuthControllerProvider);
        return switch (state.step) {
          PhoneAuthStep.enterProfile => const _PhonePage(),
          PhoneAuthStep.enterCode => const _CodePage(),
        };
      },
    );
  }
}

enum _EntryMode { create, recover }

class _PhonePage extends ConsumerStatefulWidget {
  const _PhonePage();

  @override
  ConsumerState<_PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<_PhonePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _recoveryCodeController;
  _EntryMode _mode = _EntryMode.create;
  bool _showRecoveryCode = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(phoneAuthControllerProvider);
    _nameController = TextEditingController(text: state.displayName);
    _phoneController = TextEditingController(text: state.phoneNumber);
    _recoveryCodeController = TextEditingController(text: state.recoveryCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _recoveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .startSession(
          displayName: _mode == _EntryMode.create ? _nameController.text : '',
          phoneNumber: _phoneController.text,
          recoveryCode:
              _mode == _EntryMode.recover ? _recoveryCodeController.text : null,
          recoverExisting: _mode == _EntryMode.recover,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final recovering = _mode == _EntryMode.recover;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 36,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      recovering ? '找回原来的数据' : AppCopy.appSlogan,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recovering
                          ? '使用之前登记的手机号和恢复码，继续查看原来的记录与群组。'
                          : AppCopy.onboardingSubtitle,
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<_EntryMode>(
                      segments: const [
                        ButtonSegment(
                          value: _EntryMode.create,
                          icon: Icon(Icons.person_add_alt_rounded),
                          label: Text('新账号'),
                        ),
                        ButtonSegment(
                          value: _EntryMode.recover,
                          icon: Icon(Icons.key_rounded),
                          label: Text('找回数据'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged:
                          state.isLoading
                              ? null
                              : (value) => setState(() => _mode = value.first),
                    ),
                    const SizedBox(height: 18),
                    if (!recovering) ...[
                      TextFormField(
                        controller: _nameController,
                        enabled: !state.isLoading,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.nickname],
                        decoration: const InputDecoration(
                          labelText: '大家怎么称呼你',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return '请输入一个称呼';
                          if (text.length > 12) return '称呼建议不超过 12 个字符';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _phoneController,
                      enabled: !state.isLoading,
                      keyboardType: TextInputType.phone,
                      textInputAction:
                          recovering
                              ? TextInputAction.next
                              : TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\d+\s()-]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return recovering ? '请输入原手机号' : null;
                        }
                        return PhoneNumberValidator.validate(text);
                      },
                      onFieldSubmitted: (_) {
                        if (!recovering) _submit();
                      },
                    ),
                    if (recovering) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recoveryCodeController,
                        enabled: !state.isLoading,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        obscureText: !_showRecoveryCode,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9\s-]'),
                          ),
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => newValue.copyWith(
                              text: newValue.text.toUpperCase(),
                            ),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: '恢复码',
                          prefixIcon: const Icon(Icons.key_rounded),
                          suffixIcon: IconButton(
                            tooltip: _showRecoveryCode ? '隐藏恢复码' : '显示恢复码',
                            onPressed:
                                () => setState(
                                  () => _showRecoveryCode = !_showRecoveryCode,
                                ),
                            icon: Icon(
                              _showRecoveryCode
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final text = (value ?? '').toUpperCase().replaceAll(
                            RegExp(r'[\s-]'),
                            '',
                          );
                          if (text.isEmpty) return '请输入恢复码';
                          if (text.length < 8) return '恢复码看起来太短';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: state.isLoading ? null : _submit,
                      icon:
                          state.isLoading
                              ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                recovering
                                    ? Icons.login_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                      label: Text(recovering ? '找回并进入' : '进入应用'),
                    ),
                    if (!recovering) ...[
                      const SizedBox(height: 12),
                      Text(
                        '首次进入会生成一份恢复码。换手机时，需要手机号和恢复码一起找回旧数据。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodePage extends ConsumerStatefulWidget {
  const _CodePage();

  @override
  ConsumerState<_CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<_CodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(phoneAuthControllerProvider.notifier)
        .confirmCode(_codeController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final firebaseEnabled = ref.watch(firebaseEnabledProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '更换手机号',
          onPressed:
              state.isLoading
                  ? null
                  : ref
                      .read(phoneAuthControllerProvider.notifier)
                      .changePhoneNumber,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 58,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '输入验证码',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    firebaseEnabled
                        ? '验证码已发送至 ${state.phoneNumber}'
                        : '演示验证码为 123456',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _codeController,
                    enabled: !state.isLoading,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '6 位验证码',
                      counterText: '',
                    ),
                    validator:
                        (value) => SmsCodeValidator.validate(value ?? ''),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: state.isLoading ? null : _submit,
                    child:
                        state.isLoading
                            ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('登录'),
                  ),
                  TextButton(
                    onPressed:
                        state.isLoading
                            ? null
                            : ref
                                .read(phoneAuthControllerProvider.notifier)
                                .resendCode,
                    child: const Text('重新发送验证码'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ConnectionErrorPage extends StatelessWidget {
  const _ConnectionErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('暂时无法连接云端\n请检查网络后重试。', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重新连接')),
            ],
          ),
        ),
      ),
    );
  }
}
