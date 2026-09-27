import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/animations/sky.dart';
import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../../data/providers.dart';
import '../../shared/widgets/drawing_view.dart';
import '../../shared/widgets/moment_card.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/signed_image.dart';
import '../../shared/widgets/ui.dart';
import '../creation/draft.dart';
import '../home/environment/environment_scene.dart';
import '../world/constellation_layout.dart';
import 'export_moment.dart';

final _momentFetchProvider = FutureProvider.family<Moment?, String>((ref, id) => ref.read(momentRepoProvider).get(id));

/// The few other finished moments this one most resembles (shared
/// inspirations, mood, type, time, place — the same scoring the
/// constellation uses), strongest first.
List<Moment> relatedMoments(Moment target, List<Moment> all, {int max = 3, double minSimilarity = 2}) {
  final scored = <(Moment, double)>[];
  for (final other in all) {
    if (other.id == target.id || other.isDraft) continue;
    final s = similarity(target, other);
    if (s >= minSimilarity) scored.add((other, s));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (m, _) in scored.take(max)) m];
}

class MomentDetailScreen extends ConsumerWidget {
  const MomentDetailScreen({super.key, required this.id, this.isNew = false});
  final String id;
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var m = ref.watch(momentByIdProvider(id));
    final list = ref.watch(momentsProvider);
    if (m == null) {
      final fetched = ref.watch(_momentFetchProvider(id));
      if (fetched.hasError) {
        return AtmoScaffold(
          appBar: AppBar(),
          body: ErrorState(message: friendlyError(fetched.error!), onRetry: () => ref.invalidate(_momentFetchProvider(id))),
        );
      }
      m = fetched.value;
      if (m == null) {
        if (fetched.isLoading || list.isLoading) {
          return AtmoScaffold(
            appBar: AppBar(),
            body: const Padding(padding: EdgeInsets.all(Sp.xl), child: Skeleton(height: 320)),
          );
        }
        return AtmoScaffold(
          appBar: AppBar(),
          body: EmptyState(title: context.l10n.momentDetailNotFoundTitle, message: context.l10n.momentDetailNotFoundMessage, emoji: '🌫️', actionLabel: null),
        );
      }
    }
    return _DetailBody(moment: m, isNew: isNew);
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.moment, required this.isNew});
  final Moment moment;
  final bool isNew;
  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _showKept = false;
  Timer? _keptTimer;
  final _artworkKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _showKept = true;
      _keptTimer = Timer(const Duration(seconds: 3), () => mounted ? setState(() => _showKept = false) : null);
    }
  }

  @override
  void dispose() {
    _keptTimer?.cancel();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.momentDetailDeleteTitle,
      message: l10n.momentDetailDeleteMessage,
      confirmLabel: l10n.momentDetailDeleteConfirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(momentsProvider.notifier).delete(widget.moment);
      if (!mounted) return;
      context.pop();
      showSnack(context, l10n.momentDetailDeletedSnack);
    } catch (e) {
      if (mounted) showSnack(context, l10n.momentDetailDeleteFailedSnack(friendlyError(e)));
    }
  }

  void _edit() {
    ref.read(draftProvider.notifier).loadExisting(widget.moment);
    context.push('/create/edit');
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.image_outlined), title: Text(l10n.momentDetailExportImage), onTap: () => Navigator.pop(ctx, 'image')),
            ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(l10n.momentDetailExportPdf), onTap: () => Navigator.pop(ctx, 'pdf')),
            ListTile(leading: const Icon(Icons.notes_rounded), title: Text(l10n.momentDetailExportText), onTap: () => Navigator.pop(ctx, 'text')),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final locale = Localizations.localeOf(context).toString();
    try {
      switch (choice) {
        case 'image':
          await exportMomentAsImage(_artworkKey);
        case 'pdf':
          await exportMomentAsPdf(widget.moment, l10n, locale);
        default:
          await exportMomentAsText(widget.moment, l10n, locale);
      }
    } catch (e) {
      if (mounted) showSnack(context, l10n.momentDetailExportFailed(friendlyError(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moment;
    final c = context.cm;
    final tt = context.tt;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final drawing = m.drawing;
    final answered = m.prompts.where((p) => (p.answer ?? '').trim().isNotEmpty).toList();
    final related = relatedMoments(m, ref.watch(momentsProvider).value ?? const []);
    final time = DateFormat('HH:mm', locale).format(m.createdAt);
    final date = DateFormat('MMMM d, y', locale).format(m.createdAt);
    final envIds = environmentOptions.map((o) => o.id).toSet();
    final heroEnvs = m.inspirationTypes.where(envIds.contains).toList();
    final heroHour = SkyPalette.hourFor(m.timeOfDay ?? 'auto');
    int i = 0;
    Widget stagger(Widget w) => FadeSlide(index: i++, child: w);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: MediaQuery.of(context).size.height * 0.56,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _RoundBtn(icon: Icons.arrow_back_rounded, label: l10n.momentDetailBack, onTap: () => context.pop()),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: PopupMenuButton<String>(
                      tooltip: l10n.momentDetailMoreTooltip,
                      color: c.surfaceHigh,
                      icon: const _RoundIcon(icon: Icons.more_horiz_rounded),
                      onSelected: (v) {
                        switch (v) {
                          case 'edit':
                            _edit();
                          case 'export':
                            _export();
                          default:
                            _delete();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(l10n.momentDetailEditAction, style: AppType.ui(14, color: c.text)),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Text(l10n.momentDetailExportAction, style: AppType.ui(14, color: c.text)),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.momentDetailDeleteAction, style: AppType.ui(14, color: c.danger)),
                        ),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Hero(
                    tag: 'moment-art-${m.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: RepaintBoundary(
                        key: _artworkKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EnvironmentScene(
                              overrideEnvironments: heroEnvs.isEmpty ? const ['moon'] : heroEnvs,
                              overrideAtmosphere: m.atmosphere ?? 'dreamy',
                              overrideHour: heroHour,
                            ),
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.35, 1],
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$date · $time',
                                      style: AppType.ui(13, weight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.1),
                                    ),
                                    const SizedBox(height: Sp.sm),
                                    Text(
                                      m.displayTitle(l10n),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.display(34, color: Colors.white, height: 1.05),
                                    ),
                                    if (drawing == null && m.images.isEmpty && m.excerpt.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: Sp.sm),
                                        child: Text(
                                          m.excerpt,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.display(17, style: FontStyle.italic, color: Colors.white.withValues(alpha: 0.85), height: 1.3),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      stagger(
                        Padding(
                          padding: const EdgeInsets.only(top: Sp.lg),
                          child: Wrap(
                            spacing: Sp.sm,
                            runSpacing: Sp.sm,
                            children: [
                              if (m.timeOfDay != null) _Chip('${emojiFor(timeOptions, m.timeOfDay)} ${labelFor(l10n, timeOptions, m.timeOfDay)}'),
                              for (final t in m.contentTypes) _Chip('${t.emoji} ${t.label(l10n)}'),
                              if (m.hasMusic) _Chip('🎧 ${m.musicTitle}'),
                              if (m.hasLocation) _Chip('📍 ${m.locationName}'),
                            ],
                          ),
                        ),
                      ),
                      if (m.inspirations.isNotEmpty)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.momentDetailInspiredBy.toUpperCase(), style: tt.labelSmall),
                                const SizedBox(height: Sp.sm),
                                Text(m.inspirations.map((e) => e.name).join(' · '), style: AppType.display(26, color: c.text)),
                              ],
                            ),
                          ),
                        ),
                      if (m.mood != null)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.lg),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: moodColor(m.mood)),
                                ),
                                const SizedBox(width: Sp.sm),
                                Text('${l10n.momentDetailMoodLabel}  ', style: tt.labelSmall),
                                Text(
                                  labelFor(l10n, moodOptions, m.mood),
                                  style: AppType.ui(15, weight: FontWeight.w700, color: c.text),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: Sp.xl),
                      if (drawing != null && !drawing.isEmpty)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: DrawingView(data: drawing, radius: Rd.md),
                          ),
                        ),
                      for (final img in m.images)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Rd.md),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: SignedImage(url: img.url, cacheWidth: 1200),
                              ),
                            ),
                          ),
                        ),
                      if (m.text.trim().isNotEmpty) stagger(SelectableText(m.text.trim(), style: AppType.display(23, color: c.text, height: 1.65))),
                      if (m.hasMusic)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.xl),
                            child: _MusicCard(m: m),
                          ),
                        ),
                      if (answered.isNotEmpty)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.xxl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final p in answered) ...[
                                  Text(p.question.toUpperCase(), style: tt.labelSmall),
                                  const SizedBox(height: Sp.sm),
                                  Text(
                                    '“${p.answer!.trim()}”',
                                    style: AppType.display(30, style: FontStyle.italic, color: c.text, height: 1.2),
                                  ),
                                  const SizedBox(height: Sp.xl),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (related.isNotEmpty)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(top: Sp.xxl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.momentDetailRelatedHeader.toUpperCase(), style: tt.labelSmall),
                                const SizedBox(height: Sp.md),
                                SizedBox(
                                  height: 210,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: related.length,
                                    separatorBuilder: (_, _) => const SizedBox(width: Sp.md),
                                    itemBuilder: (_, idx) => MomentCard(moment: related[idx], width: 160, height: 210, compact: true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (m.updatedAt.difference(m.createdAt).inMinutes > 5)
                        Text(l10n.momentDetailEditedAt(DateFormat('MMM d, HH:mm', locale).format(m.updatedAt)), style: tt.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showKept ? 1 : 0,
                duration: Mo.slow,
                child: Center(
                  child: Glass(
                    radius: 999,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                    child: Text(
                      context.l10n.momentDetailKeptBanner,
                      style: AppType.ui(13, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: Rd.pill,
        border: Border.all(color: c.border),
        color: c.text.withValues(alpha: 0.05),
      ),
      child: Text(
        text,
        style: AppType.ui(13, weight: FontWeight.w700, color: c.text),
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({required this.m});
  final Moment m;
  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rd.md),
        color: c.surface,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rd.sm),
            child: SizedBox(
              width: 52,
              height: 52,
              child: (m.musicArtworkUrl ?? '').isNotEmpty
                  ? Image.network(m.musicArtworkUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _NoteBox())
                  : const _NoteBox(),
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.musicTitle!, style: context.tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [m.musicArtist, m.musicAlbum].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.cm.surfaceHigh,
    child: Icon(Icons.music_note_rounded, color: context.cm.accent),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: _RoundIcon(icon: icon),
    ),
  );
}
