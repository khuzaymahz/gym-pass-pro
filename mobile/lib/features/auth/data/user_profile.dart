import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/di/providers.dart';
import 'auth_repository.dart';

/// Biological sex, collected at registration. Gyms in the catalog may be
/// male-only, female-only, or mixed, so this drives filtering and access
/// eligibility downstream. The set is intentionally closed to two values
/// because that's what gym partner policies enforce.
enum Gender {
  male,
  female;

  /// Safe reverse-lookup. `Gender.values.byName` throws on a miss — we
  /// return null instead, so stale or unknown storage values degrade
  /// gracefully to "not set" rather than crashing the app on boot.
  static Gender? fromName(String? name) {
    if (name == null) return null;
    for (final g in Gender.values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

/// SHA-256 of the password. This is a mock stand-in for a server-side
/// argon2id verifier — production mobile never stores or computes the hash;
/// it sends plaintext over TLS and the backend owns verification. Kept
/// one-way here so the secure-storage blob never carries a plaintext secret.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

class UserProfile {
  const UserProfile({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.gender,
    this.birthdate,
    this.passwordHash,
  });

  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final Gender? gender;

  /// Date of birth captured at signup. Local-only until the backend
  /// rehydrate writes it on top — used for age-gated features and
  /// the eventual personalised onboarding (birthday discount, etc.).
  final DateTime? birthdate;

  /// SHA-256 of the user's password. Null for users who signed up via Google
  /// or phone-OTP-only paths.
  final String? passwordHash;

  /// `"First Last"`, trimmed. Empty if neither part is set — callers should
  /// fall back to a locale-aware default in that case.
  String get displayName =>
      '${firstName ?? ''} ${lastName ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get isComplete =>
      (firstName ?? '').trim().isNotEmpty &&
      (lastName ?? '').trim().isNotEmpty &&
      (email ?? '').trim().isNotEmpty &&
      gender != null;

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    Gender? gender,
    DateTime? birthdate,
    String? passwordHash,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}

class ProfileStore {
  ProfileStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kFirstName = 'profile.firstName';
  static const _kLastName = 'profile.lastName';
  static const _kEmail = 'profile.email';
  static const _kPhone = 'profile.phone';
  static const _kGender = 'profile.gender';
  static const _kBirthdate = 'profile.birthdate';
  static const _kPasswordHash = 'profile.passwordHash';
  static const _kPassword = 'profile.password';

  Future<String?> readPassword() => _storage.read(key: _kPassword);
  Future<void> writePassword(String p) => _storage.write(key: _kPassword, value: p);

  Future<UserProfile> read() async {
    final firstName = await _storage.read(key: _kFirstName);
    final lastName = await _storage.read(key: _kLastName);
    final email = await _storage.read(key: _kEmail);
    final phone = await _storage.read(key: _kPhone);
    final gender = await _storage.read(key: _kGender);
    final birthdateRaw = await _storage.read(key: _kBirthdate);
    final passwordHash = await _storage.read(key: _kPasswordHash);
    return UserProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      gender: Gender.fromName(gender),
      // ISO-8601 `YYYY-MM-DD`. tryParse so a malformed legacy
      // value just returns null instead of crashing the rehydrate.
      birthdate: birthdateRaw == null ? null : DateTime.tryParse(birthdateRaw),
      passwordHash: passwordHash,
    );
  }

  Future<void> writePhone(String phone) =>
      _storage.write(key: _kPhone, value: phone);

  Future<void> writeIdentity({
    required String firstName,
    required String lastName,
    required String email,
    required Gender gender,
    required String passwordHash,
    DateTime? birthdate,
  }) async {
    await _storage.write(key: _kFirstName, value: firstName);
    await _storage.write(key: _kLastName, value: lastName);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kGender, value: gender.name);
    await _storage.write(key: _kPasswordHash, value: passwordHash);
    if (birthdate != null) {
      final iso =
          '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')}';
      await _storage.write(key: _kBirthdate, value: iso);
    } else {
      await _storage.delete(key: _kBirthdate);
    }
  }

  Future<void> writeAll({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    Gender? gender,
    String? passwordHash,
  }) async {
    if (firstName != null) {
      await _storage.write(key: _kFirstName, value: firstName);
    }
    if (lastName != null) {
      await _storage.write(key: _kLastName, value: lastName);
    }
    if (email != null) await _storage.write(key: _kEmail, value: email);
    if (phone != null) await _storage.write(key: _kPhone, value: phone);
    if (gender != null) {
      await _storage.write(key: _kGender, value: gender.name);
    }
    if (passwordHash != null) {
      await _storage.write(key: _kPasswordHash, value: passwordHash);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kFirstName);
    await _storage.delete(key: _kLastName);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPhone);
    await _storage.delete(key: _kGender);
    await _storage.delete(key: _kPasswordHash);
    await _storage.delete(key: _kPassword);
  }
}

final profileStoreProvider = Provider<ProfileStore>((ref) {
  return ProfileStore(ref.read(secureStorageProvider));
});

class ProfileController extends StateNotifier<UserProfile> {
  ProfileController(this._store, this._repo) : super(const UserProfile()) {
    _loadFuture = _load();
  }

  final ProfileStore _store;
  final AuthRepository _repo;

  late final Future<void> _loadFuture;

  /// Resolves once the persisted profile has been restored into [state].
  Future<void> get ready => _loadFuture;

  Future<void> _load() async {
    state = await _store.read();
  }

  /// Re-fetch `/me` from the backend and merge into local state.
  /// Used by pull-to-refresh on home + profile so any field an
  /// admin edited server-side (name fix, gender correction, email
  /// reset) flows back into the app without requiring a logout.
  /// Network failures keep the stale local snapshot in [state] —
  /// preferable to wiping the profile mid-session.
  ///
  /// [throwOnError] — set true from explicit user-initiated refreshes
  /// so the caller (the pull-to-refresh wrapper) can surface a
  /// snackbar instead of leaving the user thinking the refresh
  /// succeeded. Background / startup callers leave it false.
  ///
  /// Birthdate is preserved from local state because `/me`'s
  /// response shape doesn't include it yet; the field was added to
  /// the request body of `PATCH /me` but the read DTO is older.
  /// When the backend response includes birthdate, threading it
  /// through here is a one-line change.
  Future<void> refreshFromBackend({bool throwOnError = false}) async {
    try {
      final me = await _repo.fetchMe();
      // Preserve the locally-stored password hash + birthdate (the
      // `/me` endpoint doesn't return either; overwriting would
      // disable biometric login and reset the captured birthdate).
      final preservedHash = state.passwordHash;
      final preservedBirthdate = state.birthdate;
      final next = UserProfile(
        firstName: me.firstName ?? state.firstName,
        lastName: me.lastName ?? state.lastName,
        email: me.email ?? state.email,
        phone: me.phone ?? state.phone,
        gender: me.gender ?? state.gender,
        birthdate: preservedBirthdate,
        passwordHash: preservedHash,
      );
      state = next;
      // Only persist if the next state is "complete enough" for
      // the secure-storage write contract (firstName, lastName,
      // email, gender all non-null). Skip otherwise to avoid
      // overwriting a half-populated `/me` over a complete local
      // snapshot.
      if (next.firstName != null &&
          next.lastName != null &&
          next.email != null &&
          next.gender != null) {
        await _store.writeIdentity(
          firstName: next.firstName!,
          lastName: next.lastName!,
          email: next.email!,
          gender: next.gender!,
          birthdate: preservedBirthdate,
          passwordHash: preservedHash ?? '',
        );
      }
    } catch (_) {
      // Offline / token expired / 5xx — keep what we have. Rethrow
      // only when the caller asked to be told (so pull-to-refresh
      // can show a snackbar); silent otherwise.
      if (throwOnError) rethrow;
    }
  }

  /// Local-only phone update used by the OTP sign-in flow during registration.
  /// For authenticated phone-change use [requestPhoneChangeOtp] +
  /// [verifyPhoneChange] which round-trip through the backend.
  Future<void> setPhone(String phone) async {
    state = state.copyWith(phone: phone);
    await _store.writePhone(phone);
  }

  /// Ask the backend to send an OTP to a new phone for the authenticated user.
  /// Throws on validation/conflict (e.g. phone already in use).
  Future<void> requestPhoneChangeOtp(String newPhone) {
    return _repo.requestPhoneChange(newPhone);
  }

  /// Confirm the OTP and persist the new phone locally.
  Future<void> verifyPhoneChange({
    required String newPhone,
    required String code,
  }) async {
    final me = await _repo.verifyPhoneChange(newPhone: newPhone, code: code);
    final phone = me.phone ?? newPhone;
    final next = state.copyWith(phone: phone);
    state = next;
    await _store.writePhone(phone);
  }

  Future<void> setEmail(String email) async {
    state = state.copyWith(email: email);
    await _store.writeAll(email: email);
  }

  /// Stamp the password hash after a flow that proved knowledge of it
  /// (password sign-in, biometric sign-in unlocking a stored credential).
  /// The server never returns the hash, so we compute it client-side and
  /// persist it — this is what `BiometricSettingsState.hasPassword` reads
  /// to decide whether the biometric toggle is enable-able.
  Future<void> markPasswordKnown(String password) async {
    final passwordHash = hashPassword(password);
    state = state.copyWith(passwordHash: passwordHash);
    await _store.writeAll(passwordHash: passwordHash);
    await _store.writePassword(password);
  }

  /// Returns the plaintext password stored at sign-in, used by biometric
  /// enrollment so the user doesn't have to re-type it.
  Future<String?> readStoredPassword() => _store.readPassword();

  /// Replace the active session profile with a known-good record (e.g. after
  /// fetching `/me` post-login). Persists every field so a cold start
  /// rehydrates without a network round-trip.
  ///
  /// The server never returns the password hash, so a naive replace would
  /// wipe the in-memory hash on every `/me` refresh and disable the biometric
  /// toggle mid-session. Preserve any hash we already have unless the
  /// incoming profile carries its own.
  Future<void> restore(UserProfile profile) async {
    final preservedHash = profile.passwordHash ?? state.passwordHash;
    final next = profile.copyWith(passwordHash: preservedHash);
    state = next;
    await _store.writeAll(
      firstName: next.firstName,
      lastName: next.lastName,
      email: next.email,
      phone: next.phone,
      gender: next.gender,
      passwordHash: next.passwordHash,
    );
  }

  Future<void> completeRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required Gender gender,
    required String password,
    DateTime? birthdate,
  }) async {
    // Push to backend first — surface validation/email-conflict errors before
    // we mirror anything to the local store, so a failed server-side save
    // doesn't leave the mobile in a "registered locally, missing remotely"
    // limbo.
    await _repo.updateProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
      birthdate: birthdate,
      password: password,
    );
    final passwordHash = hashPassword(password);
    final next = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
      birthdate: birthdate,
      passwordHash: passwordHash,
    );
    state = next;
    await _store.writeIdentity(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
      birthdate: birthdate,
      passwordHash: passwordHash,
    );
    await _store.writePassword(password);
  }

  Future<void> updateIdentity({
    String? firstName,
    String? lastName,
    String? email,
    Gender? gender,
  }) async {
    await _repo.updateProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
    );
    final next = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
    );
    state = next;
    await _store.writeAll(
      firstName: firstName,
      lastName: lastName,
      email: email,
      gender: gender,
    );
  }

  Future<void> clear() async {
    state = const UserProfile();
    await _store.clear();
  }
}

final profileProvider =
    StateNotifierProvider<ProfileController, UserProfile>((ref) {
  return ProfileController(
    ref.read(profileStoreProvider),
    ref.read(authRepositoryProvider),
  );
});
