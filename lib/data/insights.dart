import 'models/moment.dart';

class Ranked {
  const Ranked(this.key, this.count);
  final String key;
  final int count;
}

class Insights {
  const Insights({
    this.total = 0,
    this.types = const [],
    this.inspirations = const [],
    this.moods = const [],
    this.atmospheres = const [],
    this.places = const [],
    this.artists = const [],
  });
  final int total;
  final List<Ranked> types, inspirations, moods, atmospheres, places, artists;
}

List<Ranked> _rank(Iterable<String> keys, {int take = 5}) {
  final counts = <String, int>{};
  for (final k in keys) {
    if (k.trim().isEmpty) continue;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final list = counts.entries.map((e) => Ranked(e.key, e.value)).toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list.take(take).toList();
}

/// What keeps recurring in a person's moments (no scores, just patterns).
Insights computeInsights(List<Moment> moments) => Insights(
  total: moments.length,
  types: _rank(moments.map((m) => m.type.name)),
  inspirations: _rank(moments.expand((m) => m.inspirationTypes)),
  moods: _rank(moments.map((m) => m.mood ?? '')),
  atmospheres: _rank(moments.map((m) => m.atmosphere ?? '')),
  places: _rank(moments.map((m) => m.locationName ?? '')),
  artists: _rank(moments.where((m) => m.hasMusic).map((m) => m.musicArtist ?? '')),
);
