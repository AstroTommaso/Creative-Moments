/// The signed-in account, as returned by the backend's auth endpoints.
class AppUser {
  const AppUser({required this.id, required this.email, this.displayName = '', this.avatarUrl});
  final String id, email, displayName;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    email: j['email'] as String,
    displayName: (j['displayName'] as String?) ?? '',
    avatarUrl: j['avatarUrl'] as String?,
  );
}

enum AppAuthEvent { signedIn, signedOut }

/// Emitted by [AuthRepository.changes] on sign-in / sign-out / session expiry.
class AppAuthChange {
  const AppAuthChange(this.event);
  final AppAuthEvent event;
}
