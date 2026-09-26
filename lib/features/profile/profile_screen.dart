import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/insights.dart';
import '../../data/providers.dart';
import '../../data/repositories/storage_repository.dart';
import '../../shared/widgets/signed_image.dart';
import '../../shared/widgets/ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      await ref.read(profileProvider.notifier).setAvatar(bytes, f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String current) async {
    final ctl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Your name', style: ctx.tt.headlineSmall),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Save')),
        ],
      ),
    );
    ctl.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(profileProvider.notifier).rename(name);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final moments = ref.watch(momentsProvider);
    final user = ref.watch(sessionUserProvider);
    final c = context.cm;
    final name = profile.value?.displayName ?? '';
    final avatar = profile.value?.avatarUrl;
    final ins = computeInsights(moments.value ?? const []);

    Widget section(String title, List<Ranked> items, String Function(String) label) {
      if (items.isEmpty) return const SizedBox.shrink();
      final max = items.first.count;
      return Padding(
        padding: const EdgeInsets.only(top: Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: context.tt.labelMedium?.copyWith(letterSpacing: 1.6)),
            const SizedBox(height: Sp.md),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label(r.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.ui(14, weight: FontWeight.w600, color: c.text),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(borderRadius: Rd.pill, color: c.text.withValues(alpha: 0.07)),
                          ),
                          FractionallySizedBox(
                            widthFactor: r.count / max,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: Rd.pill,
                                gradient: LinearGradient(colors: [c.accent, c.accent2]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text('${r.count}', textAlign: TextAlign.end, style: context.tt.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return AtmoScaffold(
      intensity: 0.3,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, 140),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
            ),
            Center(
              child: Semantics(
                button: true,
                label: 'Change profile photo',
                child: GestureDetector(
                  onTap: () => _pickAvatar(context, ref),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent.withValues(alpha: 0.6), width: 2),
                      boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.25), blurRadius: 30)],
                      color: c.surfaceHigh,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatar != null && avatar.isNotEmpty
                        ? SignedImage(path: avatar, bucket: StorageRepository.avatarBucket, cacheWidth: 300)
                        : Center(
                            child: Text(name.isEmpty ? '✦' : name.characters.first.toUpperCase(), style: AppType.display(48, color: c.accent)),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.lg),
            Center(
              child: GestureDetector(
                onTap: () => _rename(context, ref, name),
                child: Text(name.isEmpty ? 'Add your name' : name, style: AppType.display(38, color: c.text)),
              ),
            ),
            Center(child: Text(user?.email ?? '', style: context.tt.bodySmall)),
            const SizedBox(height: Sp.xl),
            Glass(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${ins.total}', style: AppType.display(44, color: c.accent)),
                  const SizedBox(width: Sp.md),
                  Text(ins.total == 1 ? 'moment\nkept' : 'moments\nkept', style: context.tt.bodyMedium),
                ],
              ),
            ),
            if (ins.total == 0)
              Padding(
                padding: const EdgeInsets.only(top: Sp.xl),
                child: Center(
                  child: Text('As you create, your patterns appear here.', style: context.tt.bodyMedium?.copyWith(color: c.muted)),
                ),
              )
            else ...[
              section('What you make', ins.types, (k) => '${CreationType.parse(k).emoji} ${CreationType.parse(k).label}'),
              section('Recurring inspirations', ins.inspirations, (k) => '${emojiFor(inspirationOptions, k)} ${labelFor(inspirationOptions, k)}'),
              section('Recurring moods', ins.moods, (k) => labelFor(moodOptions, k)),
              section('Atmospheres', ins.atmospheres, (k) => '${emojiFor(atmosphereOptions, k)} ${labelFor(atmosphereOptions, k)}'),
              section('Creative places', ins.places, (k) => '📍 $k'),
            ],
          ],
        ),
      ),
    );
  }
}
