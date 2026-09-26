import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';

/// How the Home subtly reflects the user's history. Purely visual: there are
/// no scores, levels or streaks anywhere.
class Evolution {
  const Evolution({this.bias = const {}, this.starBoost = 0});
  final Map<String, double> bias; // extra scene-layer presence, each ≤ 0.45
  final double starBoost; // 0..1
}

final evolutionProvider = Provider<Evolution>((ref) {
  final moments = ref.watch(momentsProvider).value ?? const [];
  if (moments.length < 3) return const Evolution();
  final n = moments.length;
  final night = moments.where((m) => m.timeOfDay == 'night').length / n;
  final counts = <String, int>{};
  for (final m in moments) {
    for (final t in m.inspirationTypes) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  double share(String k) => (counts[k] ?? 0) / n;
  double cap(double v) => (v * 0.9).clamp(0.0, 0.45);
  final growth = (n / 40).clamp(0.0, 1.0); // more moments -> a little more presence
  final bias = <String, double>{
    if (share('flowers') > 0.15) 'flowers': cap(share('flowers') * growth + 0.1),
    if (share('nature') > 0.15) 'nature': cap(share('nature') * growth + 0.1),
    if (share('ocean') > 0.15) 'ocean': cap(share('ocean') * growth + 0.1),
    if (share('rain') > 0.2) 'rain': cap(share('rain') * growth),
    if (share('city') > 0.2) 'city': cap(share('city') * growth),
  };
  return Evolution(bias: bias, starBoost: (night * 0.7 + growth * 0.3).clamp(0.0, 1.0));
});
