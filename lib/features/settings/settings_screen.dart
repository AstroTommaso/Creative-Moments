import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/preferences.dart';
import '../../data/providers.dart';
import '../../data/repositories/storage_repository.dart';
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

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'Your moments stay safe in your account.', confirmLabel: 'Log out');
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
      if (mounted) showSnack(context, 'We sent a password reset link to $email.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _deleteMoments() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete all moments?',
      message: 'Every moment, drawing and photo will be permanently removed. Your account stays.',
      confirmLabel: 'Delete all',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(momentRepoProvider).deleteAll(ref.read(sessionUserProvider)!.id);
      await ref.read(momentsProvider.notifier).refresh();
      if (mounted) showSnack(context, 'All moments deleted.');
    } catch (e) {
      if (mounted) showSnack(context, "That didn't finish. ${friendlyError(e)}");
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
          title: Text('Delete your account?', style: ctx.tt.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This permanently deletes your account, moments, drawings and photos. It cannot be undone.', style: ctx.tt.bodyMedium),
              const SizedBox(height: Sp.lg),
              TextField(
                controller: ctl,
                onChanged: (_) => set(() {}),
                decoration: const InputDecoration(hintText: 'Type DELETE to confirm'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: ctl.text.trim() == 'DELETE' ? () => Navigator.pop(ctx, true) : null,
              child: Text('Delete forever', style: TextStyle(color: ctl.text.trim() == 'DELETE' ? ctx.cm.danger : null)),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final user = ref.read(sessionUserProvider)!;
      final storage = ref.read(storageRepoProvider);
      // Storage objects can only be removed through the Storage API, so do it
      // before the account row disappears.
      await ref.read(momentRepoProvider).deleteAll(user.id);
      await storage.remove(StorageRepository.avatarBucket, await storage.listAllForUser(StorageRepository.avatarBucket, user.id));
      await ref.read(authRepoProvider).deleteAccountRow();
      try {
        await ref.read(authRepoProvider).signOut();
      } catch (_) {}
    } catch (e) {
      if (mounted) showSnack(context, "Your account couldn't be deleted. ${friendlyError(e)}");
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
      appBar: AppBar(title: const Text('Settings'), leading: const BackButton()),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: Sp.huge),
              children: [
                header('Account'),
                tile('Email', subtitle: user?.email ?? '', icon: Icons.mail_outline_rounded),
                tile('Change password', subtitle: 'We will email you a secure link', icon: Icons.lock_outline_rounded, onTap: _resetPassword),
                header('Appearance'),
                sw(
                  'Dark mode',
                  'Light mode gives the pages a warm paper tone',
                  p.darkMode,
                  (v) => _edit((q) => q.copyWith(darkMode: v)),
                  Icons.dark_mode_outlined,
                ),
                sw(
                  'Reduce motion',
                  'Calmer, still environments and no entrance animations',
                  p.reduceMotion,
                  (v) => _edit((q) => q.copyWith(reduceMotion: v)),
                  Icons.motion_photos_off_outlined,
                ),
                tile(
                  'Customize your Home',
                  subtitle: 'Environment, time, atmosphere, density',
                  icon: Icons.auto_awesome_outlined,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/customize'),
                ),
                header('Location'),
                sw('Location', 'Only used when you choose to add a place to a moment', p.locationEnabled, _toggleLocation, Icons.place_outlined),
                sw('Weather in my world', 'Lets rain or clouds appear in Home. Needs location. Approximate area only.', p.weatherEnabled && p.locationEnabled, (
                  v,
                ) async {
                  if (v && !p.locationEnabled) await _toggleLocation(true);
                  if (!mounted) return;
                  if (v && !ref.read(prefsProvider).locationEnabled) return;
                  await _edit((q) => q.copyWith(weatherEnabled: v));
                  ref.invalidate(weatherProvider);
                }, Icons.cloud_outlined),
                header('Privacy'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Sp.xl),
                  child: _PrivacyNote(),
                ),
                tile('Delete all my moments', icon: Icons.delete_sweep_outlined, color: c.danger, onTap: _busy ? null : _deleteMoments),
                header('Session'),
                tile('Log out', icon: Icons.logout_rounded, onTap: _logout),
                tile(
                  'Delete account',
                  subtitle: 'Permanently removes everything',
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
    'Everything you create is private by default. Only you can read your moments, drawings and photos; access is enforced by the database itself. Nothing is public and there is no social feed.',
    style: context.tt.bodyMedium?.copyWith(color: context.cm.muted, height: 1.5),
  );
}
