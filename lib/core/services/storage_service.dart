import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/user_progress_model.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ── Onboarding ───────────────────────────────────────

  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(AppConstants.prefOnboardingDone, true);
  }

  // ── User profile ─────────────────────────────────────

  String get firstName =>
      _prefs.getString(AppConstants.prefUserFirstName) ?? '';

  Future<void> setFirstName(String name) async {
    await _prefs.setString(AppConstants.prefUserFirstName, name);
  }

  // ── Subscription ─────────────────────────────────

  bool get isPremium =>
      _prefs.getBool(AppConstants.prefIsPremium) ?? false;

  Future<void> setIsPremium(bool value) async {
    try {
      await _prefs.setBool(AppConstants.prefIsPremium, value);
    } catch (_) {}
  }

  // ── Progress ─────────────────────────────────────────

  UserProgressModel loadProgress() {
    try {
      final raw = _prefs.getString(AppConstants.prefSessionProgress);
      if (raw == null) return const UserProgressModel();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProgressModel.fromJson(json);
    } catch (_) {
      return const UserProgressModel();
    }
  }

  Future<void> saveProgress(UserProgressModel progress) async {
    try {
      final raw = jsonEncode(progress.toJson());
      await _prefs.setString(AppConstants.prefSessionProgress, raw);
    } catch (_) {
      // Silently ignore write errors
    }
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
