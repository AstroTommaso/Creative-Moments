import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../shared/widgets/ui.dart';
import 'draft.dart';

enum _Step { inspiration, mood, music, location, question, finish }

/// After the creation itself: what inspired it, how it felt, where you were.
/// Every step is optional and can be skipped.
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});
  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  final _pages = PageController();
  int _i = 0;
  bool _busy = false;
  String? _error;
  static const _steps = _Step.values;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_steps[i] == _Step.question && ref.read(draftProvider).question == null) {
      ref.read(draftProvider.notifier).nextQuestion();
    }
    _pages.animateToPage(i, duration: Mo.slow, curve: Mo.soft);
  }

  bool _hasValue(_Step s, DraftState d) => switch (s) {
    _Step.inspiration => d.inspirations.isNotEmpty,
    _Step.mood => d.mood != null,
    _Step.music => d.music != null,
    _Step.location => d.place != null,
    _Step.question => d.questionAnswer.trim().isNotEmpty,
    _Step.finish => true,
  };

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(draftProvider.notifier).finish();
      if (!mounted) return;
      final wasNew = !ref.read(draftProvider).isEditing;
      ref.read(draftProvider.notifier).clear();
      // Replace the whole creation stack with Home + the new moment on top.
      context.go('/home');
      context.push('/moment/$id${wasNew ? '?new=1' : ''}');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final c = context.cm;
    final step = _steps[_i];
    final last = _i == _steps.length - 1;
    return AtmoScaffold(
      intensity: 0.5,
      appBar: AppBar(
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _i == 0 ? context.pop() : _go(_i - 1)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 0; k < _steps.length; k++)
              AnimatedContainer(
                duration: Mo.base,
                width: k == _i ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(borderRadius: Rd.pill, color: k <= _i ? c.accent : c.text.withValues(alpha: 0.2)),
              ),
          ],
        ),
        centerTitle: true,
        actions: [SaveChipMini(state: d)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _i = i),
                children: const [InspirationStep(), MoodStep(), MusicStep(), LocationStep(), QuestionStep(), FinishStep()],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: AppType.ui(14, weight: FontWeight.w700, color: c.danger),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.sm, Sp.xl, Sp.lg),
              child: PrimaryButton(
                label: last ? (d.isEditing ? 'Save changes' : 'Save Moment') : (_hasValue(step, d) ? 'Continue' : 'Skip'),
                loading: _busy,
                onPressed: () => last ? _finish() : _go(_i + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaveChipMini extends StatelessWidget {
  const SaveChipMini({super.key, required this.state});
  final DraftState state;
  @override
  Widget build(BuildContext context) {
    final err = state.status == SaveStatus.error;
    if (!err) return const SizedBox(width: 48);
    return Tooltip(
      message: 'Not saved yet. Retrying…',
      child: Padding(
        padding: const EdgeInsets.all(Sp.md),
        child: Icon(Icons.cloud_off_rounded, color: context.cm.danger),
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, Sp.xl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppType.display(42, color: context.cm.text, height: 1.02)),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: context.cm.muted)),
            ),
          const SizedBox(height: Sp.xl),
          child,
        ],
      ),
    );
  }
}

class InspirationStep extends ConsumerStatefulWidget {
  const InspirationStep({super.key});
  @override
  ConsumerState<InspirationStep> createState() => _InspirationStepState();
}

class _InspirationStepState extends ConsumerState<InspirationStep> {
  late final TextEditingController _other;
  @override
  void initState() {
    super.initState();
    final o = ref.read(draftProvider).inspirations.where((e) => e.type == 'other').firstOrNull;
    _other = TextEditingController(text: o?.name ?? '');
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    final selected = d.inspirations.map((e) => e.type).toSet();
    return _StepFrame(
      title: "What's inspiring\nyou right now?",
      subtitle: 'Choose anything that was in the room with you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final o in inspirationOptions)
                OptionTile(
                  emoji: o.emoji,
                  label: o.label,
                  selected: selected.contains(o.id),
                  onTap: () {
                    if (o.id == 'other') {
                      if (selected.contains('other')) {
                        _other.clear();
                        n.toggleInspiration('other');
                      } else {
                        n.toggleInspiration('other', name: 'Something else');
                      }
                    } else {
                      n.toggleInspiration(o.id);
                    }
                  },
                ),
            ],
          ),
          AnimatedSize(
            duration: Mo.base,
            curve: Mo.soft,
            child: selected.contains('other')
                ? Padding(
                    padding: const EdgeInsets.only(top: Sp.lg),
                    child: TextField(
                      controller: _other,
                      onChanged: (v) => n.setCustomInspiration(v.trim().isEmpty ? 'Something else' : v),
                      decoration: const InputDecoration(hintText: 'What was it?'),
                      style: AppType.ui(16, color: context.cm.text),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class MoodStep extends ConsumerStatefulWidget {
  const MoodStep({super.key});
  @override
  ConsumerState<MoodStep> createState() => _MoodStepState();
}

class _MoodStepState extends ConsumerState<MoodStep> {
  late final TextEditingController _custom;
  bool _other = false;
  @override
  void initState() {
    super.initState();
    final m = ref.read(draftProvider).mood;
    final known = moodOptions.any((o) => o.id == m && o.id != 'other');
    _other = m != null && !known;
    _custom = TextEditingController(text: _other && m != 'other' ? m : '');
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    return _StepFrame(
      title: 'How does this\nmoment feel?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final o in moodOptions)
                OptionTile(
                  emoji: o.emoji,
                  label: o.label,
                  selected: o.id == 'other' ? _other : (!_other && d.mood == o.id),
                  onTap: () {
                    if (o.id == 'other') {
                      setState(() => _other = true);
                      n.setMood(_custom.text.trim().isEmpty ? null : _custom.text);
                    } else {
                      setState(() => _other = false);
                      n.setMood(d.mood == o.id ? null : o.id);
                    }
                  },
                ),
            ],
          ),
          AnimatedSize(
            duration: Mo.base,
            curve: Mo.soft,
            child: _other
                ? Padding(
                    padding: const EdgeInsets.only(top: Sp.lg),
                    child: TextField(
                      controller: _custom,
                      autofocus: true,
                      maxLength: 40,
                      onChanged: n.setMood,
                      decoration: const InputDecoration(hintText: 'In your own words'),
                      style: AppType.ui(16, color: context.cm.text),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class MusicStep extends ConsumerStatefulWidget {
  const MusicStep({super.key});
  @override
  ConsumerState<MusicStep> createState() => _MusicStepState();
}

class _MusicStepState extends ConsumerState<MusicStep> {
  late final TextEditingController _title, _artist, _album;
  @override
  void initState() {
    super.initState();
    final m = ref.read(draftProvider).music;
    _title = TextEditingController(text: m?.title ?? '');
    _artist = TextEditingController(text: m?.artist ?? '');
    _album = TextEditingController(text: m?.album ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  void _push() {
    final t = _title.text.trim();
    final prev = ref.read(draftProvider).music;
    ref
        .read(draftProvider.notifier)
        .setMusic(
          t.isEmpty
              ? null
              : Music(
                  title: t,
                  artist: _artist.text.trim().isEmpty ? null : _artist.text.trim(),
                  album: _album.text.trim().isEmpty ? null : _album.text.trim(),
                  artworkUrl: prev?.artworkUrl,
                ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final style = AppType.ui(16, color: context.cm.text);
    return _StepFrame(
      title: 'What are you\nlistening to?',
      subtitle: 'Add a song by hand, or skip if it was quiet.',
      child: Column(
        children: [
          TextField(
            controller: _title,
            onChanged: (_) => _push(),
            decoration: const InputDecoration(hintText: 'Song title', prefixIcon: Icon(Icons.music_note_rounded)),
            style: style,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Sp.md),
          TextField(
            controller: _artist,
            onChanged: (_) => _push(),
            decoration: const InputDecoration(hintText: 'Artist', prefixIcon: Icon(Icons.person_outline_rounded)),
            style: style,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: Sp.md),
          TextField(
            controller: _album,
            onChanged: (_) => _push(),
            decoration: const InputDecoration(hintText: 'Album (optional)', prefixIcon: Icon(Icons.album_outlined)),
            style: style,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }
}

class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({super.key});
  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  late final TextEditingController _manual;
  bool _loading = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _manual = TextEditingController(text: ref.read(draftProvider).place?.name ?? '');
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final p = await ref.read(locationServiceProvider).current();
      ref.read(draftProvider.notifier).setPlace(Place(name: p.name, latitude: p.latitude, longitude: p.longitude));
      _manual.text = p.name;
    } catch (e) {
      // Never blocks the moment: just explain and let the person type or skip.
      _msg = friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    final c = context.cm;
    return _StepFrame(
      title: 'Where are you?',
      subtitle: 'Optional. Your location is only stored with this moment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Glass(
            semanticLabel: 'Use current location',
            onTap: _loading ? null : _locate,
            child: Row(
              children: [
                _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location_rounded, color: c.accent),
                const SizedBox(width: Sp.md),
                Expanded(child: Text('Use current location', style: context.tt.titleMedium)),
              ],
            ),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Text(
                _msg!,
                style: AppType.ui(13, weight: FontWeight.w600, color: c.danger),
              ),
            ),
          const SizedBox(height: Sp.lg),
          TextField(
            controller: _manual,
            decoration: const InputDecoration(hintText: 'Or type a place', prefixIcon: Icon(Icons.place_outlined)),
            style: AppType.ui(16, color: c.text),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => n.setPlace(
              v.trim().isEmpty
                  ? null
                  : Place(
                      name: v.trim(),
                      latitude: d.place?.name == v.trim() ? d.place?.latitude : null,
                      longitude: d.place?.name == v.trim() ? d.place?.longitude : null,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionStep extends ConsumerStatefulWidget {
  const QuestionStep({super.key});
  @override
  ConsumerState<QuestionStep> createState() => _QuestionStepState();
}

class _QuestionStepState extends ConsumerState<QuestionStep> {
  final _answer = TextEditingController();
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final n = ref.read(draftProvider.notifier);
    final c = context.cm;
    final q = d.question;
    return _StepFrame(
      title: 'A thought to\nsit with',
      subtitle: 'Answer, skip, or ask for another. Nothing here is required.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.prompts.isNotEmpty)
            for (final p in d.prompts)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Text('✓ ${p.question}', style: context.tt.bodySmall),
              ),
          if (q != null)
            AnimatedSwitcher(
              duration: Mo.slow,
              child: Glass(
                key: ValueKey(q.id),
                padding: const EdgeInsets.all(Sp.xl),
                child: Text(
                  q.text,
                  style: AppType.display(28, style: FontStyle.italic, color: c.text, height: 1.2),
                ),
              ),
            )
          else
            Text('You have seen every question we have. Lovely.', style: context.tt.bodyMedium),
          const SizedBox(height: Sp.lg),
          if (q != null)
            TextField(
              controller: _answer,
              onChanged: n.setAnswer,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: AppType.display(20, color: c.text, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Write whatever comes…',
                hintStyle: AppType.display(20, color: c.muted, style: FontStyle.italic),
              ),
            ),
          const SizedBox(height: Sp.md),
          if (q != null)
            GhostButton(
              label: 'Another question',
              icon: Icons.shuffle_rounded,
              onPressed: () {
                _answer.clear();
                n.nextQuestion();
              },
            ),
        ],
      ),
    );
  }
}

class FinishStep extends ConsumerStatefulWidget {
  const FinishStep({super.key});
  @override
  ConsumerState<FinishStep> createState() => _FinishStepState();
}

class _FinishStepState extends ConsumerState<FinishStep> {
  late final TextEditingController _title;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: ref.read(draftProvider).title);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(draftProvider);
    final c = context.cm;
    Widget row(String emoji, String text) => Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: Sp.md),
          Expanded(child: Text(text, style: context.tt.bodyLarge)),
        ],
      ),
    );
    return _StepFrame(
      title: d.isEditing ? 'Ready to keep\nthe changes?' : 'Ready to keep\nthis moment?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            onChanged: ref.read(draftProvider.notifier).setTitle,
            decoration: const InputDecoration(hintText: 'Give it a title (optional)'),
            style: AppType.display(24, weight: FontWeight.w700, color: c.text),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: Sp.xl),
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(d.type.emoji, d.type.label),
                row('🕒', '${labelFor(timeOptions, d.timeOfDay)} · ${TimeOfDay.fromDateTime(d.createdAt).format(context)}'),
                if (d.inspirations.isNotEmpty) row('✨', d.inspirations.map((e) => e.name).join(' · ')),
                if (d.mood != null) row('🫧', labelFor(moodOptions, d.mood)),
                if (d.music != null) row('🎧', [d.music!.title, d.music!.artist].whereType<String>().join(' — ')),
                if (d.place != null) row('📍', d.place!.name),
                if (d.questionAnswer.trim().isNotEmpty) row('💬', 'One answered question'),
                if (d.inspirations.isEmpty && d.mood == null && d.music == null && d.place == null)
                  Text('Nothing else added, and that is fine.', style: context.tt.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
