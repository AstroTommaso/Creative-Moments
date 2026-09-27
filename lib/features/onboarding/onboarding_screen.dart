import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/preferences.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ui.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;

  List<(String, String)> _intro(AppLocalizations l10n) => [
    (l10n.onboardStory1Title, l10n.onboardStory1Body),
    (l10n.onboardStory2Title, l10n.onboardStory2Body),
    (l10n.onboardStory3Title, l10n.onboardStory3Body),
  ];
  static const _last = 4; // 0-2 story, 3 inspirations, 4 atmosphere

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int p) => _pages.animateToPage(p, duration: Mo.slow, curve: Mo.soft);

  Future<void> _edit(UserPreferences Function(UserPreferences) f) async {
    try {
      await ref.read(preferencesProvider.notifier).edit(f);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  void _toggleEnv(String id) {
    _edit((p) {
      final list = [...p.environments];
      list.contains(id) ? list.remove(id) : list.add(id);
      return p.copyWith(environments: list, environment: list.isEmpty ? 'moon' : list.first);
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await ref.read(preferencesProvider.notifier).edit((p) {
        final insp = inspirationOptions.map((o) => o.id).toSet();
        return p.copyWith(onboarded: true, preferredInspirations: p.environments.where(insp.contains).toList());
      });
    } catch (e) {
      if (mounted) {
        showSnack(context, friendlyError(e));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    const white = Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: AtmoScaffold(
        intensity: 1,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1],
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i <= _last; i++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: Mo.base,
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(borderRadius: Rd.pill, color: i <= _page ? white : white.withValues(alpha: 0.25)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final (title, body) in _intro(context.l10n))
                        Padding(
                          padding: const EdgeInsets.all(Sp.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(title, style: AppType.display(56, color: white, height: 0.98)),
                              const SizedBox(height: Sp.lg),
                              Text(body, style: AppType.ui(17, color: white.withValues(alpha: 0.85), height: 1.5)),
                              const SizedBox(height: Sp.xl),
                            ],
                          ),
                        ),
                      _EnvironmentStep(selected: prefs.environments, onToggle: _toggleEnv),
                      _AtmosphereStep(prefs: prefs, onChange: _edit),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton(
                          tooltip: context.l10n.onboardBackTooltip,
                          onPressed: () => _go(_page - 1),
                          icon: const Icon(Icons.arrow_back_rounded, color: white),
                        ),
                      const Spacer(),
                      PrimaryButton(
                        expand: false,
                        loading: _busy,
                        label: _page == _last ? context.l10n.onboardEnterMyWorldCta : context.l10n.onboardContinueCta,
                        onPressed: () => _page == _last ? _finish() : _go(_page + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvironmentStep extends StatelessWidget {
  const _EnvironmentStep({required this.selected, required this.onToggle});
  final List<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.onboardWhatInspiresYouTitle, style: AppType.display(44, color: Colors.white, height: 1)),
          const SizedBox(height: Sp.sm),
          Text(
            context.l10n.onboardInspiresYouSubtitle,
            style: AppType.ui(15, color: Colors.white.withValues(alpha: 0.8), height: 1.45),
          ),
          const SizedBox(height: Sp.xl),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: [
              for (final o in environmentOptions) OptionTile(emoji: o.emoji, label: o.label(context.l10n), selected: selected.contains(o.id), onTap: () => onToggle(o.id)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtmosphereStep extends StatelessWidget {
  const _AtmosphereStep({required this.prefs, required this.onChange});
  final UserPreferences prefs;
  final Future<void> Function(UserPreferences Function(UserPreferences)) onChange;

  @override
  Widget build(BuildContext context) {
    Widget group(String title, List<Option> opts, String value, UserPreferences Function(UserPreferences, String) apply) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.xl, bottom: Sp.md),
          child: Text(
            title,
            style: AppType.ui(13, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.75), letterSpacing: 1),
          ),
        ),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [for (final o in opts) OptionTile(emoji: o.emoji, label: o.label(context.l10n), selected: value == o.id, onTap: () => onChange((p) => apply(p, o.id)))],
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Sp.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.onboardHowShouldItFeelTitle, style: AppType.display(44, color: Colors.white, height: 1)),
          const SizedBox(height: Sp.sm),
          Text(context.l10n.onboardChangeAnytimeSubtitle, style: AppType.ui(15, color: Colors.white.withValues(alpha: 0.8))),
          group(context.l10n.onboardAtmosphereGroupLabel, atmosphereOptions, prefs.atmosphere, (p, v) => p.copyWith(atmosphere: v)),
          group(context.l10n.onboardTimeOfDayGroupLabel, timeOptions, prefs.timeStyle, (p, v) => p.copyWith(timeStyle: v)),
          group(context.l10n.onboardVisualDensityGroupLabel, densityOptions, prefs.visualDensity, (p, v) => p.copyWith(visualDensity: v)),
        ],
      ),
    );
  }
}
