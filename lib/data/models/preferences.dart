class UserPreferences {
  const UserPreferences({
    this.environments = const ['moon', 'stars'],
    this.environment = 'moon',
    this.atmosphere = 'dreamy',
    this.timeStyle = 'auto',
    this.visualDensity = 'balanced',
    this.preferredInspirations = const [],
    this.darkMode = true,
    this.reduceMotion = false,
    this.locationEnabled = false,
    this.weatherEnabled = false,
    this.onboarded = false,
    this.language = 'system',
  });

  final List<String> environments, preferredInspirations;
  final String environment, atmosphere, timeStyle, visualDensity;
  final bool darkMode, reduceMotion, locationEnabled, weatherEnabled, onboarded;
  /// `'system'` (follow the device), `'it'` or `'en'`.
  final String language;

  UserPreferences copyWith({
    List<String>? environments,
    String? environment,
    String? atmosphere,
    String? timeStyle,
    String? visualDensity,
    List<String>? preferredInspirations,
    bool? darkMode,
    bool? reduceMotion,
    bool? locationEnabled,
    bool? weatherEnabled,
    bool? onboarded,
    String? language,
  }) => UserPreferences(
    environments: environments ?? this.environments,
    environment: environment ?? this.environment,
    atmosphere: atmosphere ?? this.atmosphere,
    timeStyle: timeStyle ?? this.timeStyle,
    visualDensity: visualDensity ?? this.visualDensity,
    preferredInspirations: preferredInspirations ?? this.preferredInspirations,
    darkMode: darkMode ?? this.darkMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    locationEnabled: locationEnabled ?? this.locationEnabled,
    weatherEnabled: weatherEnabled ?? this.weatherEnabled,
    onboarded: onboarded ?? this.onboarded,
    language: language ?? this.language,
  );

  factory UserPreferences.fromJson(Map<String, dynamic> j) {
    List<String> strs(dynamic v) => [for (final e in (v as List? ?? const [])) e as String];
    const d = UserPreferences();
    return UserPreferences(
      environments: strs(j['environments']),
      environment: (j['environment'] as String?) ?? d.environment,
      atmosphere: (j['atmosphere'] as String?) ?? d.atmosphere,
      timeStyle: (j['timeStyle'] as String?) ?? d.timeStyle,
      visualDensity: (j['visualDensity'] as String?) ?? d.visualDensity,
      preferredInspirations: strs(j['preferredInspirations']),
      darkMode: (j['darkMode'] as bool?) ?? true,
      reduceMotion: (j['reduceMotion'] as bool?) ?? false,
      locationEnabled: (j['locationEnabled'] as bool?) ?? false,
      weatherEnabled: (j['weatherEnabled'] as bool?) ?? false,
      onboarded: (j['onboarded'] as bool?) ?? false,
      language: (j['language'] as String?) ?? d.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'environments': environments,
    'environment': environment,
    'atmosphere': atmosphere,
    'timeStyle': timeStyle,
    'visualDensity': visualDensity,
    'preferredInspirations': preferredInspirations,
    'darkMode': darkMode,
    'reduceMotion': reduceMotion,
    'locationEnabled': locationEnabled,
    'weatherEnabled': weatherEnabled,
    'onboarded': onboarded,
    'language': language,
  };

  /// All active scene environments, primary first, without duplicates.
  List<String> get activeEnvironments => {environment, ...environments}.toList();
}

class Profile {
  const Profile({required this.id, this.displayName = '', this.avatarUrl});
  final String id, displayName;
  /// Ready-to-use, short-lived signed URL (or null), not a storage path.
  final String? avatarUrl;
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id'] as String, displayName: (j['displayName'] as String?) ?? '', avatarUrl: j['avatarUrl'] as String?);
}
