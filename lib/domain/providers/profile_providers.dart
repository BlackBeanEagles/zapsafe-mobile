/// Day 98 — Profile & Account state.
///
/// Covers user profile (display name, phone, member-since), biometric toggle,
/// active session management (revoke with 0.5 s mock), app cache clear
/// (1.0 s mock), and sign-out confirm flow.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Session model ────────────────────────────────────────────────────────────

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.device,
    required this.location,
    required this.lastSeen,
    required this.isCurrent,
    required this.platform,
  });

  final String id;
  final String device;
  final String location;
  final String lastSeen;
  final bool   isCurrent;
  final String platform; // 'android' | 'ios' | 'web'
}

const _kMockSessions = <SessionInfo>[
  SessionInfo(
    id:        'ses_001',
    device:    'Pixel 8 Pro',
    location:  'Mumbai, Maharashtra',
    lastSeen:  'Active now',
    isCurrent: true,
    platform:  'android',
  ),
  SessionInfo(
    id:        'ses_002',
    device:    'iPhone 15',
    location:  'Pune, Maharashtra',
    lastSeen:  '2 hours ago',
    isCurrent: false,
    platform:  'ios',
  ),
  SessionInfo(
    id:        'ses_003',
    device:    'Chrome · Windows',
    location:  'Bengaluru, Karnataka',
    lastSeen:  '3 days ago',
    isCurrent: false,
    platform:  'web',
  ),
];

// ─── State ───────────────────────────────────────────────────────────────────

class ProfileState {
  const ProfileState({
    required this.displayName,
    required this.phone,
    required this.memberSince,
    required this.biometricEnabled,
    required this.cacheMb,
    required this.sessions,
    required this.sessionsExpanded,
    required this.isEditingName,
    required this.isSavingName,
    required this.isClearingCache,
    required this.pendingName,
    required this.revokingIds,
  });

  final String            displayName;
  final String            phone;
  final DateTime          memberSince;
  final bool              biometricEnabled;
  final double            cacheMb;
  final List<SessionInfo> sessions;
  final bool              sessionsExpanded;
  final bool              isEditingName;
  final bool              isSavingName;
  final bool              isClearingCache;
  final String            pendingName;
  final Set<String>       revokingIds;

  // ── computed ─────────────────────────────────────────────────────────────

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String get memberSinceLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[memberSince.month - 1]} ${memberSince.year}';
  }

  String get cacheSizeLabel {
    if (cacheMb <= 0) return '0 KB';
    if (cacheMb < 1.0) {
      return '${(cacheMb * 1024).toStringAsFixed(0)} KB';
    }
    return '${cacheMb.toStringAsFixed(1)} MB';
  }

  bool get isSavePending =>
      pendingName.trim().isNotEmpty &&
      pendingName.trim() != displayName;

  ProfileState copyWith({
    String?            displayName,
    String?            phone,
    DateTime?          memberSince,
    bool?              biometricEnabled,
    double?            cacheMb,
    List<SessionInfo>? sessions,
    bool?              sessionsExpanded,
    bool?              isEditingName,
    bool?              isSavingName,
    bool?              isClearingCache,
    String?            pendingName,
    Set<String>?       revokingIds,
  }) {
    return ProfileState(
      displayName:      displayName      ?? this.displayName,
      phone:            phone            ?? this.phone,
      memberSince:      memberSince      ?? this.memberSince,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      cacheMb:          cacheMb          ?? this.cacheMb,
      sessions:         sessions         ?? this.sessions,
      sessionsExpanded: sessionsExpanded  ?? this.sessionsExpanded,
      isEditingName:    isEditingName    ?? this.isEditingName,
      isSavingName:     isSavingName     ?? this.isSavingName,
      isClearingCache:  isClearingCache  ?? this.isClearingCache,
      pendingName:      pendingName      ?? this.pendingName,
      revokingIds:      revokingIds      ?? this.revokingIds,
    );
  }
}

// ─── Initial state ────────────────────────────────────────────────────────────

final _kInitial = ProfileState(
  displayName:      'Alex Morgan',
  phone:            '+91 98765 43210',
  memberSince:      DateTime(2026, 2, 14),
  biometricEnabled: true,
  cacheMb:          12.4,
  sessions:         _kMockSessions,
  sessionsExpanded: false,
  isEditingName:    false,
  isSavingName:     false,
  isClearingCache:  false,
  pendingName:      '',
  revokingIds:      const <String>{},
);

// ─── Notifier ────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(_kInitial);

  void startEditName() => state = state.copyWith(
        isEditingName: true,
        pendingName: state.displayName,
      );

  void updatePendingName(String v) => state = state.copyWith(pendingName: v);

  void cancelEditName() => state = state.copyWith(
        isEditingName: false,
        pendingName: '',
      );

  Future<void> saveName() async {
    final trimmed = state.pendingName.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(isSavingName: true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(
      displayName:   trimmed,
      isEditingName: false,
      isSavingName:  false,
      pendingName:   '',
    );
  }

  void toggleBiometric() =>
      state = state.copyWith(biometricEnabled: !state.biometricEnabled);

  void toggleSessionsExpanded() =>
      state = state.copyWith(sessionsExpanded: !state.sessionsExpanded);

  Future<void> revokeSession(String id) async {
    state = state.copyWith(revokingIds: {...state.revokingIds, id});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(
      sessions:    state.sessions.where((s) => s.id != id).toList(),
      revokingIds: state.revokingIds.difference({id}),
    );
  }

  Future<void> clearCache() async {
    state = state.copyWith(isClearingCache: true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(cacheMb: 0.0, isClearingCache: false);
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(),
);
