import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/sky.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/providers.dart';
import 'evolution.dart';
import 'scene_model.dart';
import 'scene_painter.dart';

/// The user's living environment. [intensity] fades it back on screens where
/// concentration matters (1 = Home, ~0.25 = list screens).
class EnvironmentScene extends ConsumerStatefulWidget {
  const EnvironmentScene({
    super.key,
    this.intensity = 1,
    this.parallax,
    this.quality = 1,
    this.overrideHour,
    this.overrideEnvironments,
    this.overrideAtmosphere,
  });
  final double intensity, quality;
  final ValueListenable<double>? parallax;
  final double? overrideHour;
  /// When set (e.g. reliving a past moment), these replace the live
  /// environment mix and atmosphere instead of reading current preferences,
  /// and today's weather/evolution bias are skipped — neither applies to a
  /// historical snapshot.
  final List<String>? overrideEnvironments;
  final String? overrideAtmosphere;

  @override
  ConsumerState<EnvironmentScene> createState() => _EnvironmentSceneState();
}

class _EnvironmentSceneState extends ConsumerState<EnvironmentScene> with SingleTickerProviderStateMixin {
  final model = SceneModel();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.parallax?.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.parallax?.removeListener(_onScroll);
    _ticker.dispose();
    model.dispose();
    super.dispose();
  }

  void _onScroll() {
    model.parallax = widget.parallax!.value;
    if (_reduce) model.tick();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    model.t = (model.t + dt) % 60;
    // ease presence toward target: layers fade / grow in gently
    final k = 1 - math.pow(0.001, dt / 1.6).toDouble();
    for (final e in model.target.entries) {
      final cur = model.presence[e.key] ?? 0;
      final next = cur + (e.value - cur) * k;
      model.presence[e.key] = (next - e.value).abs() < 0.002 ? e.value : next;
    }
    for (final key in model.presence.keys.toList()) {
      if (!model.target.containsKey(key)) {
        final cur = model.presence[key]!;
        final next = cur - cur * k;
        if (next < 0.002) {
          model.presence.remove(key);
        } else {
          model.presence[key] = next;
        }
      }
    }
    model.tick();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final weather = ref.watch(weatherProvider).value;
    final evo = ref.watch(evolutionProvider);
    _reduce = prefs.reduceMotion || MediaQuery.of(context).disableAnimations;

    final historical = widget.overrideEnvironments != null;
    final active = widget.overrideEnvironments ?? prefs.activeEnvironments;
    final target = <String, double>{};
    for (var i = 0; i < active.length; i++) {
      target[active[i]] = i == 0 ? 1.0 : 0.72;
    }
    if (!historical) {
      // Home slowly evolves with what the user makes.
      for (final e in evo.bias.entries) {
        target[e.key] = ((target[e.key] ?? 0) + e.value).clamp(0.0, 1.0);
      }
      if (weather != null) {
        switch (weather) {
          case Weather.rain:
            target['rain'] = 0.9;
          case Weather.cloudy:
            target['clouds'] = 0.9;
          case Weather.snow:
            target['winter'] = 0.9;
          case Weather.clear || Weather.fog:
            break;
        }
      }
    }
    model
      ..target = target
      ..atmosphere = widget.overrideAtmosphere ?? prefs.atmosphere
      ..weather = historical ? null : weather
      ..starBoost = historical ? 0 : evo.starBoost
      ..density = switch (prefs.visualDensity) {
        'subtle' => 0.55,
        'immersive' => 1.3,
        _ => 1.0,
      }
      ..quality = widget.quality;
    model.hour = widget.overrideHour ?? SkyPalette.hourFor(prefs.timeStyle) ?? _nowHour();

    if (_reduce) {
      _ticker.stop();
      model.presence = Map.of(target);
      model.t = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? model.tick() : null);
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }

    final c = context.cm;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: ScenePainter(model), size: Size.infinite),
          if (widget.intensity < 1)
            AnimatedContainer(
              duration: Mo.slow,
              color: c.bg.withValues(alpha: (1 - widget.intensity).clamp(0.0, 1.0)),
            ),
        ],
      ),
    );
  }

  double _nowHour() {
    final n = DateTime.now();
    return n.hour + n.minute / 60;
  }
}
