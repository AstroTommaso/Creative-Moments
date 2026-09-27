import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../shared/widgets/ui.dart';
import 'auth_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AtmoScaffold(
        intensity: 1,
        quality: 1,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sp.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 3),
                Text(
                  context.l10n.appBrandName,
                  style: AppType.display(64, weight: FontWeight.w500, color: Colors.white, height: 0.95),
                ),
                const SizedBox(height: Sp.lg),
                Text(
                  context.l10n.authWelcomeSubtitle,
                  style: AppType.ui(17, color: Colors.white.withValues(alpha: 0.82), height: 1.5),
                ),
                const Spacer(flex: 2),
                PrimaryButton(label: context.l10n.authBeginCta, onPressed: () => context.push('/register')),
                const SizedBox(height: Sp.sm),
                Center(
                  child: GhostButton(label: context.l10n.authAlreadyHaveAccount, color: Colors.white, onPressed: () => context.push('/login')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).signIn(email: _email.text, password: _pw.text);
      // router redirect takes over on the auth state change
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: context.l10n.authLoginTitle,
      subtitle: context.l10n.authLoginSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              Field(controller: _email, label: context.l10n.authEmailLabel, keyboard: TextInputType.emailAddress, validator: (v) => validateEmail(context.l10n, v), autofill: const [AutofillHints.email]),
              Field(
                controller: _pw,
                label: context.l10n.authPasswordLabel,
                obscure: true,
                validator: (v) => (v ?? '').isEmpty ? context.l10n.authEnterPasswordError : null,
                autofill: const [AutofillHints.password],
                action: TextInputAction.done,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        InlineError(_error),
        PrimaryButton(label: context.l10n.authSignInCta, onPressed: _submit, loading: _busy),
        const SizedBox(height: Sp.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GhostButton(label: context.l10n.authForgotPasswordCta, onPressed: () => context.push('/forgot')),
            GhostButton(label: context.l10n.authCreateAccountCta, onPressed: () => context.go('/register')),
          ],
        ),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pw = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).signUp(email: _email.text, password: _pw.text, name: _name.text);
      // router redirect takes over on the auth state change
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: context.l10n.authRegisterTitle,
      subtitle: context.l10n.authRegisterSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              Field(
                controller: _name,
                label: context.l10n.authNameLabel,
                autofill: const [AutofillHints.givenName],
                validator: (v) => (v ?? '').trim().isEmpty ? context.l10n.authWhatShouldWeCallYouError : null,
              ),
              Field(controller: _email, label: context.l10n.authEmailLabel, keyboard: TextInputType.emailAddress, validator: (v) => validateEmail(context.l10n, v), autofill: const [AutofillHints.email]),
              Field(
                controller: _pw,
                label: context.l10n.authPasswordWithHintLabel,
                obscure: true,
                validator: (v) => validatePassword(context.l10n, v),
                autofill: const [AutofillHints.newPassword],
                action: TextInputAction.done,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
        InlineError(_error),
        PrimaryButton(label: context.l10n.authCreateAccountCta, onPressed: _submit, loading: _busy),
        const SizedBox(height: Sp.sm),
        Center(
          child: GhostButton(label: context.l10n.authAlreadyHaveAccount, onPressed: () => context.go('/login')),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotState();
}

class _ForgotState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: context.l10n.authResetPasswordTitle,
      subtitle: _sent
          ? context.l10n.authResetLinkSentSubtitle
          : context.l10n.authResetPasswordSubtitle,
      children: [
        if (!_sent) ...[
          Form(
            key: _form,
            child: Field(
              controller: _email,
              label: context.l10n.authEmailLabel,
              keyboard: TextInputType.emailAddress,
              validator: (v) => validateEmail(context.l10n, v),
              action: TextInputAction.done,
              onSubmitted: _submit,
            ),
          ),
          InlineError(_error),
          PrimaryButton(label: context.l10n.authSendLinkCta, onPressed: _submit, loading: _busy),
        ] else
          PrimaryButton(label: context.l10n.authBackToSignInCta, onPressed: () => context.go('/login')),
      ],
    );
  }
}

