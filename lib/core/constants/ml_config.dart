import 'app_constants.dart';

class MlConfig {
  // Nilai akan disesuaikan dengan model asli saat integrasi ML
  static const double lowConfidenceThreshold = 0.6;
  
  static bool showScanPoints = AppConstants.gamificationEnabled;
  static const int scanPointsReward = 15;
}
