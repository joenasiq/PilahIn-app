class AppConstants {
  static const String demoEmail = 'kel5pbl@gmail.com';
  static const String demoPassword = 'pilahln123';
  static const String demoDisplayName = 'Kelompok Baiq';

  // SharedPreferences Keys
  static const String keyUserSession = 'user_session';
  static const String keyIsGuest = 'is_guest';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyUserId = 'user_id';
  static const String keyRegisteredAccounts = 'registered_accounts';

  // Aturan akun
  static const int minPasswordLength = 8;
  static const String demoUserId = 'user_1';
  static const String guestUserId = 'guest_id';

  // Gamifikasi: poin dasar sementara (dummy) khusus akun demo & tamu
  static const int dummyBasePoints = 850;

  // Kunci penyimpanan gamifikasi (di-prefix dengan id akun)
  static const String keyDailyPointsPrefix = 'daily_points';
  static const String keyLoginPointsPrefix = 'login_points';
  static const String keyLoginStreakPrefix = 'login_streak';
  static const String keyLastLoginClaimPrefix = 'last_login_claim';
  static const String keyClaimedBadgesPrefix = 'claimed_badges';
  static const String keyClaimedMissionsPrefix = 'claimed_missions';
  static const String keyMissionPointsPrefix = 'mission_points';
  static const String loginStreakBadgeId = 'login_streak_7';

  // Demo Flags
  static const bool seedDemoHistory = false;

  // Gamification Flag
  static const bool gamificationEnabled = true;

  // Media Flag
  static bool showMediaPlaceholders = true;
}
