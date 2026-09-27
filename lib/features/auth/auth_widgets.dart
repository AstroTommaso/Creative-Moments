import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ui.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.title, this.subtitle, required this.children, this.showBack = true, this.intensity = 0.55});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return AtmoScaffold(
      intensity: intensity,
      quality: 0.6,
      appBar: showBack ? AppBar(leading: const BackButton()) : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: AppType.display(42, color: context.cm.text, height: 1.05)),
                  ),
                  if (subtitle != null) ...[const SizedBox(height: Sp.sm), Text(subtitle!, style: context.tt.bodyLarge?.copyWith(color: context.cm.muted))],
                  const SizedBox(height: Sp.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboard,
    this.validator,
    this.autofill,
    this.action = TextInputAction.next,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final Iterable<String>? autofill;
  final TextInputAction action;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: autofill,
        textInputAction: action,
        validator: validator,
        onFieldSubmitted: (_) => onSubmitted?.call(),
        style: AppType.ui(16, color: context.cm.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppType.ui(15, color: context.cm.muted),
        ),
      ),
    );
  }
}

String? validateEmail(AppLocalizations l10n, String? v) {
  final s = (v ?? '').trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return l10n.authInvalidEmailError;
  return null;
}

String? validatePassword(AppLocalizations l10n, String? v) => (v ?? '').length < 8 ? l10n.authPasswordTooShortError : null;

class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message!,
          style: AppType.ui(14, weight: FontWeight.w600, color: context.cm.danger),
        ),
      ),
    );
  }
}
