import 'dart:math';

import 'package:creative_moments/core/constants/question_library.dart';
import 'package:creative_moments/core/utils/question_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library has unique ids and a broad set of questions', () {
    final ids = questionLibrary.map((q) => q.id).toSet();
    expect(ids.length, questionLibrary.length);
    expect(questionLibrary.length, greaterThanOrEqualTo(60));
  });

  test('writing + rain surfaces the rain-and-writing question', () {
    final sel = QuestionSelector(random: Random(1));
    final seen = <String>{};
    for (var i = 0; i < 40; i++) {
      seen.add(sel.pick(const QuestionContext(type: 'writing', inspirations: {'rain'}))!.id);
    }
    expect(seen, contains('r1'));
    // and never something built for a different creation type
    for (final id in seen) {
      final q = questionLibrary.firstWhere((e) => e.id == id);
      expect(q.types.isEmpty || q.types.contains('writing'), isTrue, reason: id);
    }
  });

  test('drawing + moon can ask where the drawing would exist in the universe', () {
    final sel = QuestionSelector(random: Random(3));
    final texts = {
      for (var i = 0; i < 30; i++) sel.pick(const QuestionContext(type: 'drawing', inspirations: {'moon'}))!.text,
    };
    expect(texts, contains('If this drawing existed somewhere in the universe, where would it be?'));
  });

  test('time of day and mood steer selection', () {
    final sel = QuestionSelector(random: Random(5));
    final night = {for (var i = 0; i < 40; i++) sel.pick(const QuestionContext(type: 'writing', timeOfDay: 'night'))!.id};
    expect(night, contains('t1'));
    final lonely = {for (var i = 0; i < 40; i++) sel.pick(const QuestionContext(type: 'drawing', mood: 'lonely'))!.id};
    expect(lonely.any((id) => id == 'mo1' || id == 'mo2'), isTrue);
  });

  test('a generic context still gets a question', () {
    expect(QuestionSelector(random: Random(2)).pick(const QuestionContext(type: 'freeform')), isNotNull);
  });

  test('excluded questions never repeat and the library can be exhausted', () {
    final sel = QuestionSelector(random: Random(9));
    final shown = <String>{};
    const ctx = QuestionContext(type: 'story', inspirations: {'ocean'}, mood: 'calm', timeOfDay: 'night');
    while (true) {
      final q = sel.pick(ctx, exclude: shown);
      if (q == null) break;
      expect(shown.add(q.id), isTrue, reason: 'repeated ${q.id}');
    }
    expect(shown.length, questionLibrary.length);
  });

  test('randomises between equally good matches', () {
    final results = <String>{};
    for (var seed = 0; seed < 25; seed++) {
      results.add(QuestionSelector(random: Random(seed)).pick(const QuestionContext(type: 'idea'))!.id);
    }
    expect(results.length, greaterThan(1));
  });
}
