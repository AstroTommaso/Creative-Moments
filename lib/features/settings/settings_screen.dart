import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/preferences.dart';
import '../../data/providers.dart';
import '../../shared/widgets/ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _edit(UserPreferences Function(UserPreferences) f) async {
    try {
      await ref.read(preferencesProvider.notifier).edit(f);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _toggleLocation(bool on) async {
    if (on) {
      try {
        await ref.read(locationServiceProvider).position();
      } catch (e) {
        if (!mounted) return;
        showSnack(context, friendlyError(e));
        if (e is AppError && e.message.contains('settings')) await Geolocator.openAppSettings();
        return;
      }
    }
    await _edit((p) => p.copyWith(locationEnabled: on, weatherEnabled: on ? p.weatherEnabled : false));
  }

  String _languageLabel(BuildContext context, String language) => switch (language) {
    'it' => context.l10n.settingsLanguageItalian,
    'en' => context.l10n.settingsLanguageEnglish,
    _ => context.l10n.settingsLanguageSystem,
  };

  Future<void> _pickLanguage() async {
    final current = ref.read(prefsProvider).language;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in const ['system', 'it', 'en'])
              ListTile(
                title: Text(_languageLabel(ctx, code)),
                trailing: code == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, code),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != current) await _edit((q) => q.copyWith(language: chosen));
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: context.l10n.settingsLogoutTitle,
      message: context.l10n.settingsLogoutMessage,
      confirmLabel: context.l10n.settingsLogoutConfirm,
    );
    if (!ok) return;
    try {
      await ref.read(authRepoProvider).signOut();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _resetPassword() async {
    final email = ref.read(sessionUserProvider)?.email;
    if (email == null) return;
    try {
      await ref.read(authRepoProvider).sendPasswordReset(email);
      if (mounted) showSnack(context, context.l10n.settingsResetLinkSent(email));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _deleteMoments() async {
    final ok = await confirmDialog(
      context,
      title: context.l10n.settingsDeleteMomentsTitle,
      message: context.l10n.settingsDeleteMomentsMessage,
      confirmLabel: context.l10n.settingsDeleteMomentsConfirm,
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(momentRepoProvider).deleteAll(ref.read(sessionUserProvider)!.id);
      await ref.read(momentsProvider.notifier).refresh();
      if (mounted) showSnack(context, context.l10n.settingsAllMomentsDeleted);
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.settingsDeleteMomentsFailed(friendlyError(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(ctx.l10n.settingsDeleteAccountTitle, style: ctx.tt.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.l10n.settingsDeleteAccountWarning, style: ctx.tt.bodyMedium),
              const SizedBox(height: Sp.lg),
              TextField(
                controller: ctl,
                onChanged: (_) => set(() {}),
                decoration: InputDecoration(hintText: ctx.l10n.settingsDeleteAccountHint),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.settingsCancel)),
            TextButton(
              // Safety confirmation compares against the literal English word "DELETE" (not translated).
              onPressed: ctl.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: Text(ctx.l10n.settingsDeleteForever, style: TextStyle(color: ctl.text.trim() == 'DELETE' ? ctx.cm.danger : null)),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      // The backend deletes storage files and every row atomically.
      await ref.read(authRepoProvider).deleteAccountRow();
      try {
        await ref.read(authRepoProvider).signOut();
      } catch (_) {}
    } catch (e) {
      if (mounted) showSnack(context, context.l10n.settingsDeleteAccountFailed(friendlyError(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(prefsProvider);
    final user = ref.watch(sessionUserProvider);
    final c = context.cm;

    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, Sp.sm),
      child: Text(t.toUpperCase(), style: context.tt.labelMedium?.copyWith(letterSpacing: 1.6)),
    );
    Widget tile(String title, {String? subtitle, Widget? trailing, VoidCallback? onTap, Color? color, IconData? icon}) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
      minVerticalPadding: Sp.md,
      leading: icon == null ? null : Icon(icon, color: color ?? c.muted),
      title: Text(
        title,
        style: AppType.ui(16, weight: FontWeight.w600, color: color ?? c.text),
      ),
      subtitle: subtitle == null ? null : Text(subtitle, style: context.tt.bodySmall),
      trailing: trailing,
      onTap: onTap,
    );
    Widget sw(String title, String subtitle, bool v, ValueChanged<bool> on, IconData icon) => SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
      secondary: Icon(icon, color: c.muted),
      title: Text(
        title,
        style: AppType.ui(16, weight: FontWeight.w600, color: c.text),
      ),
      subtitle: Text(subtitle, style: context.tt.bodySmall),
      value: v,
      onChanged: on,
    );

    return AtmoScaffold(
      intensity: 0.12,
      quality: 0.2,
      appBar: AppBar(title: Text(context.l10n.settingsTitle), leading: const BackButton()),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: Sp.huge),
              children: [
                header(context.l10n.settingsSectionAccount),
                tile(context.l10n.settingsEmailTitle, subtitle: user?.email ?? '', icon: Icons.mail_outline_rounded),
                tile(
                  context.l10n.settingsChangePasswordTitle,
                  subtitle: context.l10n.settingsChangePasswordSubtitle,
                  icon: Icons.lock_outline_rounded,
                  onTap: _resetPassword,
                ),
                header(context.l10n.settingsSectionAppearance),
                sw(
                  context.l10n.settingsDarkModeTitle,
                  context.l10n.settingsDarkModeSubtitle,
                  p.darkMode,
                  (v) => _edit((q) => q.copyWith(darkMode: v)),
                  Icons.dark_mode_outlined,
                ),
                sw(
                  context.l10n.settingsReduceMotionTitle,
                  context.l10n.settingsReduceMotionSubtitle,
                  p.reduceMotion,
                  (v) => _edit((q) => q.copyWith(reduceMotion: v)),
                  Icons.motion_photos_off_outlined,
                ),
                tile(
                  context.l10n.settingsCustomizeHomeTitle,
                  subtitle: context.l10n.settingsCustomizeHomeSubtitle,
                  icon: Icons.auto_awesome_outlined,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/customize'),
                ),
                tile(
                  context.l10n.settingsLanguageTitle,
                  subtitle: _languageLabel(context, p.language),
                  icon: Icons.language_outlined,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickLanguage,
                ),
                header(context.l10n.settingsSectionLocation),
                sw(
                  context.l10n.settingsLocationTitle,
                  context.l10n.settingsLocationSubtitle,
                  p.locationEnabled,
                  _toggleLocation,
                  Icons.place_outlined,
                ),
                sw(context.l10n.settingsWeatherTitle, context.l10n.settingsWeatherSubtitle, p.weatherEnabled && p.locationEnabled, (
                  v,
                ) async {
                  if (v && !p.locationEnabled) await _toggleLocation(true);
                  if (!mounted) return;
                  if (v && !ref.read(prefsProvider).locationEnabled) return;
                  await _edit((q) => q.copyWith(weatherEnabled: v));
                  ref.invalidate(weatherProvider);
                }, Icons.cloud_outlined),
                header(context.l10n.settingsSectionPrivacy),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Sp.xl),
                  child: _PrivacyNote(),
                ),
                tile(
                  context.l10n.settingsDeleteMomentsTileTitle,
                  icon: Icons.delete_sweep_outlined,
                  color: c.danger,
                  onTap: _busy ? null : _deleteMoments,
                ),
                header(context.l10n.settingsSectionSession),
                tile(context.l10n.settingsLogoutTileTitle, icon: Icons.logout_rounded, onTap: _logout),
                tile(
                  context.l10n.settingsDeleteAccountTileTitle,
                  subtitle: context.l10n.settingsDeleteAccountTileSubtitle,
                  icon: Icons.delete_forever_outlined,
                  color: c.danger,
                  onTap: _busy ? null : _deleteAccount,
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black38,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();
  @override
  Widget build(BuildContext context) => Text(
    context.l10n.settingsPrivacyNote,
    style: context.tt.bodyMedium?.copyWith(color: context.cm.muted, height: 1.5),
  );
}
