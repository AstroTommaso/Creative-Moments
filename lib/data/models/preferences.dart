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
  });

  final List<String> environments, preferredInspirations;
  final String environment, atmosphere, timeStyle, visualDensity;
  final bool darkMode, reduceMotion, locationEnabled, weatherEnabled, onboarded;

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
  );

  factory UserPreferences.fromJson(Map<String, dynamic> j) {
    List<String> strs(dynamic v) => [for (final e in (v as List? ?? const [])) e as String];
    const d = UserPreferences();
    return UserPreferences(
      environments: strs(j['environments']),
      environment: (j['environment'] as String?) ?? d.environment,
      atmosphere: (j['atmosphere'] as String?) ?? d.atmosphere,
      timeStyle: (j['time_style'] as String?) ?? d.timeStyle,
      visualDensity: (j['visual_density'] as String?) ?? d.visualDensity,
      preferredInspirations: strs(j['preferred_inspirations']),
      darkMode: (j['dark_mode'] as bool?) ?? true,
      reduceMotion: (j['reduce_motion'] as bool?) ?? false,
      locationEnabled: (j['location_enabled'] as bool?) ?? false,
      weatherEnabled: (j['weather_enabled'] as bool?) ?? false,
      onboarded: (j['onboarded'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson(String userId) => {
    'user_id': userId,
    'environments': environments,
    'environment': environment,
    'atmosphere': atmosphere,
    'time_style': timeStyle,
    'visual_density': visualDensity,
    'preferred_inspirations': preferredInspirations,
    'dark_mode': darkMode,
    'reduce_motion': reduceMotion,
    'location_enabled': locationEnabled,
    'weather_enabled': weatherEnabled,
    'onboarded': onboarded,
  };

  /// All active scene environments, primary first, without duplicates.
  List<String> get activeEnvironments => {environment, ...environments}.toList();
}

class Profile {
  const Profile({required this.id, this.displayName = '', this.avatarUrl});
  final String id, displayName;
  final String? avatarUrl; // storage path in the avatars bucket
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id'] as String, displayName: (j['display_name'] as String?) ?? '', avatarUrl: j['avatar_url'] as String?);
}
