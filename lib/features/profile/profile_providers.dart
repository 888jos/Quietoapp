import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_progress_model.dart';
import '../../core/services/storage_providers.dart';
import '../../core/services/storage_service.dart';
import '../player/player_providers.dart';

// ── État ──────────────────────────────────────────────

class ProfileState {
  final String firstName;
  final bool notificationsEnabled;

  const ProfileState({
    this.firstName = '',
    this.notificationsEnabled = false,
  });

  ProfileState copyWith({String? firstName, bool? notificationsEnabled}) =>
      ProfileState(
        firstName: firstName ?? this.firstName,
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
      );
}

// ── Notifier ──────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final StorageService _storage;
  final Ref _ref;

  ProfileNotifier(this._storage, this._ref) : super(const ProfileState()) {
    _load();
  }

  void _load() {
    state = ProfileState(
      firstName: _storage.firstName,
      notificationsEnabled: _storage.notificationsEnabled,
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

  Future<void> toggleNotifications(bool value) async {
    try {
      await _storage.setNotificationsEnabled(value);
      state = state.copyWith(notificationsEnabled: value);
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
  return ProfileNotifier(ref.watch(storageServiceProvider), ref);
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
