class AppUser {
  final String id;
  final String email;
  final String displayName;
  final bool isGuest;

  /// URL foto profil di Firebase Storage (null bila belum diatur).
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.isGuest = false,
    this.photoUrl,
  });

  factory AppUser.guest() {
    return const AppUser(
      id: 'guest_id',
      email: '',
      displayName: 'Tamu',
      isGuest: true,
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    bool? isGuest,
    String? photoUrl,
    bool clearPhotoUrl = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
    );
  }
}
