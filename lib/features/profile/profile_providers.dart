import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/storage_providers.dart';
import '../../core/services/storage_service.dart';

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

  ProfileNotifier(this._storage) : super(const ProfileState()) {
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
      await _storage.setFirstName(name.trim());
      state = state.copyWith(firstName: name.trim());
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
  return ProfileNotifier(ref.watch(storageServiceProvider));
});
