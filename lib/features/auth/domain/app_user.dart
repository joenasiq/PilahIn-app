class AppUser {
  final String id;
  final String email;
  final String displayName;
  final bool isGuest;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.isGuest = false,
  });

  factory AppUser.guest() {
    return const AppUser(
      id: 'guest_id',
      email: '',
      displayName: 'Tamu',
      isGuest: true,
    );
  }
}
