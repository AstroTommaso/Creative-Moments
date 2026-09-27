import 'package:flutter/material.dart' show Color;

import '../../l10n/app_localizations.dart';

class Option {
  const Option(this.id, this.emoji, this.label);
  final String id, emoji;
  final String Function(AppLocalizations l10n) label;
}

enum CreationType {
  writing('✍️'),
  drawing('🎨'),
  story('📖'),
  letter('💌'),
  photo('📸'),
  idea('💭'),
  voice('🎙️'),
  freeform('✨');

  const CreationType(this.emoji);
  final String emoji;

  static CreationType parse(String? v) => CreationType.values.firstWhere((e) => e.name == v, orElse: () => CreationType.freeform);

  /// Types that can be started from the create picker today.
  static const selectable = [writing, drawing, story, letter, photo, idea, freeform];

  bool get isText => this == writing || this == story || this == letter || this == idea;

  String label(AppLocalizations l10n) => switch (this) {
    CreationType.writing => l10n.creationTypeWriting,
    CreationType.drawing => l10n.creationTypeDrawing,
    CreationType.story => l10n.creationTypeStory,
    CreationType.letter => l10n.creationTypeLetter,
    CreationType.photo => l10n.creationTypePhoto,
    CreationType.idea => l10n.creationTypeIdea,
    CreationType.voice => l10n.creationTypeVoice,
    CreationType.freeform => l10n.creationTypeFreeform,
  };
}

final environmentOptions = <Option>[
  Option('moon', '🌙', (l) => l.envMoon),
  Option('stars', '🌌', (l) => l.envStars),
  Option('flowers', '🌸', (l) => l.envFlowers),
  Option('nature', '🌿', (l) => l.envNature),
  Option('ocean', '🌊', (l) => l.envOcean),
  Option('mountains', '🏔️', (l) => l.envMountains),
  Option('desert', '🏜️', (l) => l.envDesert),
  Option('city', '🌃', (l) => l.envCity),
  Option('rain', '🌧️', (l) => l.envRain),
  Option('clouds', '☁️', (l) => l.envClouds),
  Option('sunset', '🌅', (l) => l.envSunset),
  Option('fire', '🔥', (l) => l.envFire),
  Option('autumn', '🍂', (l) => l.envAutumn),
  Option('winter', '❄️', (l) => l.envWinter),
  Option('abstract', '✨', (l) => l.envAbstract),
];

final inspirationOptions = <Option>[
  Option('moon', '🌙', (l) => l.inspMoon),
  Option('rain', '🌧️', (l) => l.inspRain),
  Option('ocean', '🌊', (l) => l.inspOcean),
  Option('stars', '🌌', (l) => l.inspStars),
  Option('flowers', '🌸', (l) => l.inspFlowers),
  Option('nature', '🌿', (l) => l.inspNature),
  Option('desert', '🏜️', (l) => l.inspDesert),
  Option('city', '🌃', (l) => l.inspCity),
  Option('music', '🎵', (l) => l.inspMusic),
  Option('seen', '📷', (l) => l.inspSeen),
  Option('memory', '💭', (l) => l.inspMemory),
  Option('feeling', '❤️', (l) => l.inspFeeling),
  Option('person', '👤', (l) => l.inspPerson),
  Option('place', '📍', (l) => l.inspPlace),
  Option('other', '✨', (l) => l.inspOther),
];

final moodOptions = <Option>[
  Option('calm', '🌫️', (l) => l.moodCalm),
  Option('dreamy', '🫧', (l) => l.moodDreamy),
  Option('nostalgic', '🎞️', (l) => l.moodNostalgic),
  Option('happy', '☀️', (l) => l.moodHappy),
  Option('melancholic', '🌧️', (l) => l.moodMelancholic),
  Option('romantic', '🌹', (l) => l.moodRomantic),
  Option('energetic', '⚡', (l) => l.moodEnergetic),
  Option('lonely', '🌑', (l) => l.moodLonely),
  Option('peaceful', '🕊️', (l) => l.moodPeaceful),
  Option('confused', '🌀', (l) => l.moodConfused),
  Option('inspired', '💫', (l) => l.moodInspired),
  Option('other', '✏️', (l) => l.moodOther),
];

final atmosphereOptions = <Option>[
  Option('dreamy', '🫧', (l) => l.atmosphereDreamy),
  Option('calm', '🌫️', (l) => l.atmosphereCalm),
  Option('mystical', '🔮', (l) => l.atmosphereMystical),
  Option('warm', '🕯️', (l) => l.atmosphereWarm),
  Option('dark', '🌑', (l) => l.atmosphereDark),
  Option('romantic', '🌹', (l) => l.atmosphereRomantic),
  Option('natural', '🌿', (l) => l.atmosphereNatural),
  Option('energetic', '⚡', (l) => l.atmosphereEnergetic),
];

final timeOptions = <Option>[
  Option('auto', '🕒', (l) => l.timeAuto),
  Option('dawn', '🌄', (l) => l.timeDawn),
  Option('day', '☀️', (l) => l.timeDay),
  Option('sunset', '🌇', (l) => l.timeSunset),
  Option('night', '🌙', (l) => l.timeNight),
];

final densityOptions = <Option>[
  Option('subtle', '·', (l) => l.densitySubtle),
  Option('balanced', '◦', (l) => l.densityBalanced),
  Option('immersive', '●', (l) => l.densityImmersive),
];

Option? findOption(List<Option> list, String? id) {
  for (final o in list) {
    if (o.id == id) return o;
  }
  return null;
}

String labelFor(AppLocalizations l10n, List<Option> list, String? id) => findOption(list, id)?.label(l10n) ?? (id ?? '');
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

/// [name] is the person's first name, or '' to use the plain greeting.
String greetingForHour(AppLocalizations l10n, int h, {String name = ''}) {
  if (h < 5) return name.isEmpty ? l10n.greetingStillAwake : l10n.greetingStillAwakeNamed(name);
  if (h < 12) return name.isEmpty ? l10n.greetingGoodMorning : l10n.greetingGoodMorningNamed(name);
  if (h < 18) return name.isEmpty ? l10n.greetingGoodAfternoon : l10n.greetingGoodAfternoonNamed(name);
  return name.isEmpty ? l10n.greetingGoodEvening : l10n.greetingGoodEveningNamed(name);
}

String promptForHour(AppLocalizations l10n, int h) {
  if (h < 5 || h >= 21) return l10n.promptTonight;
  if (h < 12) return l10n.promptMorning;
  if (h < 18) return l10n.promptToday;
  return l10n.promptEvening;
}

/// 'dawn' | 'day' | 'sunset' | 'night' — an internal key, never shown to the user.
String timeOfDayFor(DateTime t) {
  final h = t.hour + t.minute / 60;
  if (h >= 5 && h < 10) return 'dawn';
  if (h >= 10 && h < 17) return 'day';
  if (h >= 17 && h < 20.5) return 'sunset';
  return 'night';
}
