import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_progress_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/storage_providers.dart';
import '../../core/services/storage_service.dart';
import '../player/player_providers.dart';

// ── État ──────────────────────────────────────────────

class ProfileState {
  final String firstName;
  final bool notificationsEnabled;

  /// Heure du rappel quotidien (null tant que jamais choisie).
  final TimeOfDay? reminderTime;

  const ProfileState({
    this.firstName = '',
    this.notificationsEnabled = false,
    this.reminderTime,
  });

  ProfileState copyWith({
    String? firstName,
    bool? notificationsEnabled,
    TimeOfDay? reminderTime,
  }) =>
      ProfileState(
        firstName: firstName ?? this.firstName,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
      );
}

// ── Notifier ──────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final StorageService _storage;
  final NotificationService _notifications;
  final Ref _ref;

  ProfileNotifier(this._storage, this._notifications, this._ref)
      : super(const ProfileState()) {
    _load();
  }

  void _load() {
    final hour = _storage.reminderHour;
    final minute = _storage.reminderMinute;
    state = ProfileState(
      firstName: _storage.firstName,
      notificationsEnabled: _storage.notificationsEnabled,
      reminderTime: (hour != null && minute != null)
          ? TimeOfDay(hour: hour, minute: minute)
          : null,
    );
  }

  Future<void> setFirstName(String name) async {
    try {
      final trimmed = name.trim();
      await _storage.setFirstName(trimmed);
      state = state.copyWith(firstName: trimmed);
      _ref.read(firstNameProvider.notifier).state = trimmed;
    } catch (_) {}
  }

  /// Heure effective du rappel : celle choisie par l'utilisateur, sinon un
  /// défaut dérivé de sa réponse Q4 d'onboarding (moment préféré).
  TimeOfDay get _effectiveReminderTime {
    final stored = state.reminderTime;
    if (stored != null) return stored;
    final d = defaultReminderTime(_storage.getOnboardingAnswers());
    return TimeOfDay(hour: d.hour, minute: d.minute);
  }

  /// Active/désactive le rappel quotidien. À l'activation : demande la
  /// permission système — si refusée, le toggle reste éteint (pas de fausse
  /// promesse). Retourne true si l'opération a abouti.
  Future<bool> toggleNotifications(bool value) async {
    try {
      if (!value) {
        await _notifications.cancelDailyReminder();
        await _storage.setNotificationsEnabled(false);
        state = state.copyWith(notificationsEnabled: false);
        return true;
      }

      final granted = await _notifications.requestPermission();
      if (!granted) return false;

      final time = _effectiveReminderTime;
      await _storage.setReminderTime(time.hour, time.minute);
      await _storage.setNotificationsEnabled(true);
      await _notifications.scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
        firstName: _storage.firstName,
      );
      state = state.copyWith(
        notificationsEnabled: true,
        reminderTime: time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Active le rappel à [time] en supposant la permission déjà accordée
  /// (utilisé par la proposition post-première-séance, qui demande la
  /// permission elle-même au bon moment).
  Future<void> enableReminderAt(TimeOfDay time, {bool skipToday = false}) async {
    try {
      await _storage.setReminderTime(time.hour, time.minute);
      await _storage.setNotificationsEnabled(true);
      await _notifications.scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
        skipToday: skipToday,
        firstName: _storage.firstName,
      );
      state = state.copyWith(notificationsEnabled: true, reminderTime: time);
    } catch (_) {}
  }

  /// Change l'heure du rappel et reprogramme si le rappel est actif.
  Future<void> setReminderTime(TimeOfDay time) async {
    try {
      await _storage.setReminderTime(time.hour, time.minute);
      state = state.copyWith(reminderTime: time);
      if (state.notificationsEnabled) {
        await _notifications.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
          firstName: _storage.firstName,
        );
      }
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    try {
      await _storage.resetOnboarding();
    } catch (_) {}
  }
}

// ── Provider ──────────────────────────────────────────

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(
    ref.watch(storageServiceProvider),
    ref.watch(notificationServiceProvider),
    ref,
  );
});

/// Progrès utilisateur (minutes méditées + séances complétées).
/// Réactif : se rafraîchit automatiquement à chaque fois qu'une séance est
/// marquée complétée par l'audio handler (via sessionCompletionTickProvider).
/// Sans ça, les stats affichées sur la page Profil ne changeraient pas avant
/// un redémarrage de l'app.
final userProgressProvider = Provider<UserProgressModel>((ref) {
  ref.watch(sessionCompletionTickProvider);
  return ref.watch(storageServiceProvider).loadProgress();
});
