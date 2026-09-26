import 'dart:math';

import '../constants/question_library.dart';

class QuestionContext {
  const QuestionContext({required this.type, this.inspirations = const {}, this.mood, this.timeOfDay, this.environments = const {}});
  final String type;
  final Set<String> inspirations;
  final String? mood, timeOfDay;
  final Set<String> environments;
}

/// Scores the library against a context and picks randomly among the best
/// matches so prompts stay relevant without repeating.
class QuestionSelector {
  QuestionSelector({Random? random, List<Question>? library}) : _rng = random ?? Random(), _lib = library ?? questionLibrary;
  final Random _rng;
  final List<Question> _lib;

  int score(Question q, QuestionContext c) {
    var s = 0;
    if (q.types.contains(c.type)) s += 3;
    s += 3 * q.inspirations.intersection(c.inspirations).length;
    if (c.mood != null && q.moods.contains(c.mood)) s += 2;
    if (c.timeOfDay != null && q.times.contains(c.timeOfDay)) s += 2;
    s += q.envs.intersection(c.environments).isNotEmpty ? 1 : 0;
    // A question that names a context the moment does not have is a poor fit.
    if (q.types.isNotEmpty && !q.types.contains(c.type)) s -= 5;
    if (q.inspirations.isNotEmpty && q.inspirations.intersection(c.inspirations).isEmpty) s -= 2;
    if (q.moods.isNotEmpty && (c.mood == null || !q.moods.contains(c.mood))) s -= 2;
    if (q.times.isNotEmpty && (c.timeOfDay == null || !q.times.contains(c.timeOfDay))) s -= 2;
    return s;
  }

  /// Picks a question not in [exclude]. Returns null only if the library is exhausted.
  Question? pick(QuestionContext c, {Set<String> exclude = const {}}) {
    final pool = _lib.where((q) => !exclude.contains(q.id)).toList();
    if (pool.isEmpty) return null;
    final scored = pool.map((q) => (q, score(q, c))).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    final best = scored.first.$2;
    // Take everything within 2 points of the best so there is variety.
    final top = scored.where((e) => e.$2 >= best - 2 && e.$2 > -3).map((e) => e.$1).toList();
    final source = top.isEmpty ? [scored.first.$1] : top;
    return source[_rng.nextInt(source.length)];
  }
}
