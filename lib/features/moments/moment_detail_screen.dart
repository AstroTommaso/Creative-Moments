import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
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

final _momentFetchProvider = FutureProvider.family<Moment?, String>((ref, id) => ref.read(momentRepoProvider).get(id));

String relativeDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return d.hour >= 18 || d.hour < 5 ? 'Tonight' : 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE').format(d);
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
          body: EmptyState(title: 'Moment not found', message: 'It may have been deleted.', emoji: '🌫️', actionLabel: null),
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
    final ok = await confirmDialog(
      context,
      title: 'Delete this moment?',
      message: 'This removes it and everything attached to it. It cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(momentsProvider.notifier).delete(widget.moment);
      if (!mounted) return;
      context.pop();
      showSnack(context, 'Moment deleted.');
    } catch (e) {
      if (mounted) showSnack(context, "It couldn't be deleted. ${friendlyError(e)}");
    }
  }

  void _edit() {
    ref.read(draftProvider.notifier).loadExisting(widget.moment);
    context.push('/create/edit');
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.moment;
    final c = context.cm;
    final tt = context.tt;
    final drawing = m.drawing;
    final answered = m.prompts.where((p) => (p.answer ?? '').trim().isNotEmpty).toList();
    final time = DateFormat('HH:mm').format(m.createdAt);
    final date = DateFormat('MMMM d, y').format(m.createdAt);
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
                expandedHeight: MediaQuery.of(context).size.height * 0.42,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _RoundBtn(icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => context.pop()),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: PopupMenuButton<String>(
                      tooltip: 'More',
                      color: c.surfaceHigh,
                      icon: const _RoundIcon(icon: Icons.more_horiz_rounded),
                      onSelected: (v) => v == 'edit' ? _edit() : _delete(),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit', style: AppType.ui(14, color: c.text)),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: AppType.ui(14, color: c.danger)),
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
                      child: SizedBox.expand(child: MomentArtwork(moment: m)),
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
                      stagger(Text(relativeDay(m.createdAt), style: AppType.display(54, color: c.text, height: 1))),
                      stagger(
                        Padding(
                          padding: const EdgeInsets.only(top: Sp.sm),
                          child: Text('$date · $time', style: tt.bodyMedium?.copyWith(color: c.muted)),
                        ),
                      ),
                      stagger(
                        Padding(
                          padding: const EdgeInsets.only(top: Sp.lg),
                          child: Wrap(
                            spacing: Sp.sm,
                            runSpacing: Sp.sm,
                            children: [
                              if (m.timeOfDay != null) _Chip('${emojiFor(timeOptions, m.timeOfDay)} ${labelFor(timeOptions, m.timeOfDay)}'),
                              _Chip('${m.type.emoji} ${m.type.label}'),
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
                                Text('INSPIRED BY', style: tt.labelSmall),
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
                                Text('Mood  ', style: tt.labelSmall),
                                Text(
                                  labelFor(moodOptions, m.mood),
                                  style: AppType.ui(15, weight: FontWeight.w700, color: c.text),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: Sp.xl),
                      if (m.title.trim().isNotEmpty)
                        stagger(
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: Text(
                              m.title,
                              style: AppType.display(36, weight: FontWeight.w700, color: c.text, height: 1.1),
                            ),
                          ),
                        ),
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
                      if (m.updatedAt.difference(m.createdAt).inMinutes > 5)
                        Text('Edited ${DateFormat('MMM d, HH:mm').format(m.updatedAt)}', style: tt.bodySmall),
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
                      '✦  Kept in your world',
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
