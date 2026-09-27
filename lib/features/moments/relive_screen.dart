import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/animations/sky.dart';
import '../../core/constants/catalog.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../../shared/widgets/drawing_view.dart';
import '../../shared/widgets/signed_image.dart';
import '../../shared/widgets/ui.dart';
import '../home/environment/environment_scene.dart';

/// Slowly reconstructs the atmosphere a moment was made in — its time of
/// day, environment, music, creation and answered question — instead of
/// just showing the record of it. Nothing here is live: the scene is fed
/// this moment's own signals, not today's preferences or weather.
class ReliveMomentScreen extends StatelessWidget {
  const ReliveMomentScreen({super.key, required this.moment});
  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final envIds = environmentOptions.map((o) => o.id).toSet();
    final envs = moment.inspirationTypes.where(envIds.contains).toList();
    final answered = moment.prompts.where((p) => (p.answer ?? '').trim().isNotEmpty).toList();
    final drawing = moment.drawing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          EnvironmentScene(
            overrideEnvironments: envs.isEmpty ? const ['moon'] : envs,
            overrideAtmosphere: moment.atmosphere ?? 'dreamy',
            overrideHour: SkyPalette.hourFor(moment.timeOfDay ?? 'auto'),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1],
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(Sp.md),
                    child: Glass(
                      radius: 999,
                      padding: EdgeInsets.zero,
                      semanticLabel: l10n.momentDetailBack,
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, Sp.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('MMMM d, y · HH:mm', locale).format(moment.createdAt),
                          style: AppType.ui(13, weight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.1),
                        ),
                        const SizedBox(height: Sp.sm),
                        Text(
                          moment.displayTitle(l10n),
                          style: AppType.display(38, color: Colors.white, height: 1.05),
                        ),
                        const SizedBox(height: Sp.xl),
                        if (drawing != null && !drawing.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: DrawingView(data: drawing, radius: Rd.md),
                          ),
                        for (final img in moment.images)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(Rd.md),
                              child: AspectRatio(aspectRatio: 4 / 3, child: SignedImage(url: img.url, cacheWidth: 1200)),
                            ),
                          ),
                        if (moment.text.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: Text(
                              moment.text.trim(),
                              style: AppType.display(22, color: Colors.white, height: 1.6),
                            ),
                          ),
                        if (moment.hasMusic)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: Colors.white70, size: 18),
                                const SizedBox(width: Sp.sm),
                                Flexible(
                                  child: Text(
                                    [moment.musicTitle, moment.musicArtist].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                                    style: AppType.ui(14, weight: FontWeight.w600, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (moment.hasLocation)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined, color: Colors.white70, size: 18),
                                const SizedBox(width: Sp.sm),
                                Text(moment.locationName!, style: AppType.ui(14, weight: FontWeight.w600, color: Colors.white70)),
                              ],
                            ),
                          ),
                        for (final p in answered)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Sp.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.question, style: AppType.ui(12, weight: FontWeight.w700, color: Colors.white54, letterSpacing: 0.6)),
                                const SizedBox(height: Sp.xs),
                                Text(
                                  '“${p.answer!.trim()}”',
                                  style: AppType.display(24, style: FontStyle.italic, color: Colors.white, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
