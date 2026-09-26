import 'package:flutter/material.dart';

class Option {
  const Option(this.id, this.emoji, this.label);
  final String id, emoji, label;
}

enum CreationType {
  writing('✍️', 'Writing'),
  drawing('🎨', 'Drawing'),
  story('📖', 'Story'),
  letter('💌', 'Letter'),
  photo('📸', 'Photo'),
  idea('💭', 'Idea'),
  voice('🎙️', 'Voice'),
  freeform('✨', 'Freeform');

  const CreationType(this.emoji, this.label);
  final String emoji, label;

  static CreationType parse(String? v) => CreationType.values.firstWhere((e) => e.name == v, orElse: () => CreationType.freeform);

  /// Types that can be started from the create picker today.
  static const selectable = [writing, drawing, story, letter, photo, idea, freeform];

  bool get isText => this == writing || this == story || this == letter || this == idea;
}

const environmentOptions = <Option>[
  Option('moon', '🌙', 'Moon'),
  Option('stars', '🌌', 'Stars'),
  Option('flowers', '🌸', 'Flowers'),
  Option('nature', '🌿', 'Nature'),
  Option('ocean', '🌊', 'Ocean'),
  Option('mountains', '🏔️', 'Mountains'),
  Option('desert', '🏜️', 'Desert'),
  Option('city', '🌃', 'City'),
  Option('rain', '🌧️', 'Rain'),
  Option('clouds', '☁️', 'Clouds'),
  Option('sunset', '🌅', 'Sunset'),
  Option('fire', '🔥', 'Fire'),
  Option('autumn', '🍂', 'Autumn'),
  Option('winter', '❄️', 'Winter'),
  Option('abstract', '✨', 'Abstract'),
];

const inspirationOptions = <Option>[
  Option('moon', '🌙', 'Moon'),
  Option('rain', '🌧️', 'Rain'),
  Option('ocean', '🌊', 'Ocean'),
  Option('stars', '🌌', 'Stars'),
  Option('flowers', '🌸', 'Flowers'),
  Option('nature', '🌿', 'Nature'),
  Option('desert', '🏜️', 'Desert'),
  Option('city', '🌃', 'City'),
  Option('music', '🎵', 'Music'),
  Option('seen', '📷', 'Something I saw'),
  Option('memory', '💭', 'A memory'),
  Option('feeling', '❤️', 'A feeling'),
  Option('person', '👤', 'A person'),
  Option('place', '📍', 'A place'),
  Option('other', '✨', 'Something else'),
];

const moodOptions = <Option>[
  Option('calm', '🌫️', 'Calm'),
  Option('dreamy', '🫧', 'Dreamy'),
  Option('nostalgic', '🎞️', 'Nostalgic'),
  Option('happy', '☀️', 'Happy'),
  Option('melancholic', '🌧️', 'Melancholic'),
  Option('romantic', '🌹', 'Romantic'),
  Option('energetic', '⚡', 'Energetic'),
  Option('lonely', '🌑', 'Lonely'),
  Option('peaceful', '🕊️', 'Peaceful'),
  Option('confused', '🌀', 'Confused'),
  Option('inspired', '💫', 'Inspired'),
  Option('other', '✏️', 'Other'),
];

const atmosphereOptions = <Option>[
  Option('dreamy', '🫧', 'Dreamy'),
  Option('calm', '🌫️', 'Calm'),
  Option('mystical', '🔮', 'Mystical'),
  Option('warm', '🕯️', 'Warm'),
  Option('dark', '🌑', 'Dark'),
  Option('romantic', '🌹', 'Romantic'),
  Option('natural', '🌿', 'Natural'),
  Option('energetic', '⚡', 'Energetic'),
];

const timeOptions = <Option>[
  Option('auto', '🕒', 'Follow the clock'),
  Option('dawn', '🌄', 'Dawn'),
  Option('day', '☀️', 'Day'),
  Option('sunset', '🌇', 'Sunset'),
  Option('night', '🌙', 'Night'),
];

const densityOptions = <Option>[Option('subtle', '·', 'Subtle'), Option('balanced', '◦', 'Balanced'), Option('immersive', '●', 'Immersive')];

Option? findOption(List<Option> list, String? id) {
  for (final o in list) {
    if (o.id == id) return o;
  }
  return null;
}

String labelFor(List<Option> list, String? id) => findOption(list, id)?.label ?? (id ?? '');
String emojiFor(List<Option> list, String? id) => findOption(list, id)?.emoji ?? '✨';

/// Color identity for moods (used on cards, calendar, constellation).
Color moodColor(String? mood) => switch (mood) {
  'calm' => const Color(0xFF7FB6C9),
  'dreamy' => const Color(0xFFB59CFF),
  'nostalgic' => const Color(0xFFD9A66B),
  'happy' => const Color(0xFFFFCF6B),
  'melancholic' => const Color(0xFF6C86C9),
  'romantic' => const Color(0xFFE88BA6),
  'energetic' => const Color(0xFFFF8A5B),
  'lonely' => const Color(0xFF8E8AA8),
  'peaceful' => const Color(0xFF8FD1B0),
  'confused' => const Color(0xFFB88FD9),
  'inspired' => const Color(0xFFF2D27A),
  _ => const Color(0xFFA6A3D9),
};

String greetingForHour(int h) {
  if (h < 5) return 'Still awake.';
  if (h < 12) return 'Good morning.';
  if (h < 18) return 'Good afternoon.';
  return 'Good evening.';
}

String promptForHour(int h) {
  if (h < 5 || h >= 21) return 'What are you inspired by tonight?';
  if (h < 12) return 'What is stirring in you this morning?';
  if (h < 18) return 'What is inspiring you today?';
  return 'What are you inspired by this evening?';
}

/// 'dawn' | 'day' | 'sunset' | 'night'
String timeOfDayFor(DateTime t) {
  final h = t.hour + t.minute / 60;
  if (h >= 5 && h < 10) return 'dawn';
  if (h >= 10 && h < 17) return 'day';
  if (h >= 17 && h < 20.5) return 'sunset';
  return 'night';
}
