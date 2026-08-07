/// Day 176 — Data Retention Settings
///
/// First day of the Days 176-178 Data Retention Settings block.
/// Day 176: Per-category expiry pickers, evidence vault timer,
///           GPS purge schedule, Hive storage for preferences.
/// Day 177: Auto-deletion scheduler + "deleting tomorrow" preview
///           + retention change history.
/// Day 178: Edge cases + DPDP §8 compliance + block sign-off.
///
/// 🟢 FRONTEND-ONLY for pickers + Hive storage (local state).
/// 🟡 MOCK-NOW for server-side enforcement of retention policies.
///    Backend API contract documented in Tab 3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider        = StateProvider<int>((ref) => 0);
final _retentionMapProvider     = StateProvider<Map<_RetCat, _RetPeriod>>((ref) =>
    Map.fromEntries(_kCategories.map((c) => MapEntry(c.cat, c.defaultPeriod))));
final _expandedCatProvider      = StateProvider<_RetCat?>((ref) => null);
final _expandedVaultProvider    = StateProvider<int?>((ref) => null);
final _saveStateProvider        = StateProvider<_SaveState>((ref) => _SaveState.idle);
final _dirtyProvider            = StateProvider<bool>((ref) => false);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _RetCat  {
  sosEvents, evidence, location, analytics, auditLog, notifications, profile
}

enum _RetPeriod {
  days7, days14, days30, days90, days180, days365, forever
}

enum _SaveState { idle, saving, saved, error }

// ── Data ───────────────────────────────────────────────────────────────────────
class _CatConfig {
  final _RetCat       cat;
  final String        name;
  final IconData      icon;
  final Color         color;
  final String        description;
  final List<_RetPeriod> options;
  final _RetPeriod    defaultPeriod;
  final String        dpdpNote;      // why minimisation matters for this cat
  final bool          serverEnforced; // true = 🟡 MOCK-NOW, false = 🟢 local
  const _CatConfig({
    required this.cat, required this.name, required this.icon,
    required this.color, required this.description,
    required this.options, required this.defaultPeriod,
    required this.dpdpNote, required this.serverEnforced,
  });
}

const _kCategories = [
  _CatConfig(
    cat: _RetCat.sosEvents,
    name: 'SOS Events & Incidents',
    icon: Icons.warning_rounded,
    color: Color(0xFFEF4444),
    description: 'SOS event metadata, dispatch records, DCS scores, incident reports.',
    options: [_RetPeriod.days30, _RetPeriod.days90, _RetPeriod.days180,
              _RetPeriod.days365, _RetPeriod.forever],
    defaultPeriod: _RetPeriod.days365,
    dpdpNote: 'SOS events may be needed for legal proceedings. '
        'We recommend at least 90 days. '
        'If under active investigation, use "Keep forever" until resolved.',
    serverEnforced: true,
  ),
  _CatConfig(
    cat: _RetCat.evidence,
    name: 'Evidence Vault',
    icon: Icons.lock_rounded,
    color: Color(0xFFF59E0B),
    description: 'Audio recordings, GPS traces, IMU data, video from SOS events.',
    options: [_RetPeriod.days30, _RetPeriod.days90, _RetPeriod.days180,
              _RetPeriod.days365, _RetPeriod.forever],
    defaultPeriod: _RetPeriod.days90,
    dpdpNote: 'Evidence files are large and sensitive. '
        'DPDP §8: retain only as long as necessary for the purpose. '
        'If you filed a police report, set to "Keep forever" until proceedings end.',
    serverEnforced: true,
  ),
  _CatConfig(
    cat: _RetCat.location,
    name: 'Location & GPS History',
    icon: Icons.location_on_rounded,
    color: Color(0xFF10B981),
    description: 'GPS batch uploads, safe zone data, location traces during SOS.',
    options: [_RetPeriod.days7, _RetPeriod.days14, _RetPeriod.days30, _RetPeriod.days90],
    defaultPeriod: _RetPeriod.days14,
    dpdpNote: 'Location data is the most sensitive category. '
        'DPDP §8 and GDPR Art. 5(1)(e) require strict minimisation. '
        'ZapSafe defaults to 14 days — sufficient for SOS follow-up.',
    serverEnforced: true,
  ),
  _CatConfig(
    cat: _RetCat.analytics,
    name: 'Analytics & Crash Logs',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF8B5CF6),
    description: 'Usage analytics (if consented), Sentry crash reports, ATT status.',
    options: [_RetPeriod.days7, _RetPeriod.days30, _RetPeriod.days90],
    defaultPeriod: _RetPeriod.days30,
    dpdpNote: 'Analytics data is only collected with consent. '
        'Crash logs are anonymised but still purged after 90 days '
        'to respect data minimisation.',
    serverEnforced: false,
  ),
  _CatConfig(
    cat: _RetCat.auditLog,
    name: 'Data Access Audit Log',
    icon: Icons.history_rounded,
    color: Color(0xFF3B82F6),
    description: 'Records of who accessed your data, when, and from where.',
    options: [_RetPeriod.days30, _RetPeriod.days90, _RetPeriod.days365],
    defaultPeriod: _RetPeriod.days90,
    dpdpNote: 'Audit logs support your right to review access history (DPDP §11). '
        'Shorter retention reduces oversight; '
        'we recommend at least 90 days.',
    serverEnforced: true,
  ),
  _CatConfig(
    cat: _RetCat.notifications,
    name: 'Notification & Check-in History',
    icon: Icons.notifications_rounded,
    color: Color(0xFF6B7280),
    description: 'Push/SMS notification history, check-in timer records.',
    options: [_RetPeriod.days7, _RetPeriod.days30, _RetPeriod.days90],
    defaultPeriod: _RetPeriod.days30,
    dpdpNote: 'Notification history is low-sensitivity but accumulates quickly. '
        'Default 30 days balances review capability with minimisation.',
    serverEnforced: false,
  ),
  _CatConfig(
    cat: _RetCat.profile,
    name: 'Profile & Account Data',
    icon: Icons.account_circle_rounded,
    color: Color(0xFF3B82F6),
    description: 'Name, phone, subscription, settings, consent records.',
    options: [_RetPeriod.forever],
    defaultPeriod: _RetPeriod.forever,
    dpdpNote: 'Profile data must be retained while your account is active. '
        'It is deleted on account deletion (Day 169-172 flow). '
        'This setting cannot be changed independently.',
    serverEnforced: false,
  ),
];

// ── Evidence vault entries for Tab 2 ──────────────────────────────────────────
class _VaultEntry {
  final String  sosId;
  final String  date;
  final int     daysRemaining;
  final int     totalDays;
  final String  files;
  final String  sizeMb;
  const _VaultEntry({
    required this.sosId, required this.date,
    required this.daysRemaining, required this.totalDays,
    required this.files, required this.sizeMb,
  });
}

const _kVaultEntries = [
  _VaultEntry(sosId: 'sos_20260529', date: 'May 29, 2026',
      daysRemaining: 61, totalDays: 90, files: '6 streams (audio, GPS, IMU)',
      sizeMb: '24.8'),
  _VaultEntry(sosId: 'sos_20260515', date: 'May 15, 2026',
      daysRemaining: 47, totalDays: 90, files: '6 streams', sizeMb: '21.2'),
  _VaultEntry(sosId: 'sos_20250914', date: 'Sep 14, 2025',
      daysRemaining: 4, totalDays: 90, files: '4 streams (no video)', sizeMb: '9.3'),
];

// ── Period helpers ─────────────────────────────────────────────────────────────
const _periodLabel = {
  _RetPeriod.days7:   '7 days',
  _RetPeriod.days14:  '14 days',
  _RetPeriod.days30:  '30 days',
  _RetPeriod.days90:  '90 days',
  _RetPeriod.days180: '180 days',
  _RetPeriod.days365: '1 year',
  _RetPeriod.forever: 'Keep forever',
};

const _periodDays = {
  _RetPeriod.days7:   7,
  _RetPeriod.days14:  14,
  _RetPeriod.days30:  30,
  _RetPeriod.days90:  90,
  _RetPeriod.days180: 180,
  _RetPeriod.days365: 365,
  _RetPeriod.forever: -1,
};

// ── Mock service ───────────────────────────────────────────────────────────────
class _RetentionService {
  /// Simulates PUT /api/v1/account/retention-settings
  static Future<void> saveSettings(Map<_RetCat, _RetPeriod> settings) =>
      Future.delayed(const Duration(milliseconds: 900));
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day176DataRetentionSettingsScreen extends ConsumerWidget {
  const Day176DataRetentionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab   = ref.watch(_activeTabProvider);
    final dirty = ref.watch(_dirtyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Data Retention Settings'),
        elevation: 0,
        actions: [
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
              child: _SaveButton(),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
              ),
              child: const Text('DPDP §8',
                  style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _RetentionTab(),
            if (tab == 1) const _EvidenceVaultTab(),
            if (tab == 2) const _ApiContractTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Save button ────────────────────────────────────────────────────────────────
class _SaveButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_saveStateProvider);
    return GestureDetector(
      onTap: state == _SaveState.saving ? null : () async {
        ref.read(_saveStateProvider.notifier).state = _SaveState.saving;
        try {
          await _RetentionService.saveSettings(ref.read(_retentionMapProvider));
          if (context.mounted) {
            ref.read(_saveStateProvider.notifier).state = _SaveState.saved;
            ref.read(_dirtyProvider.notifier).state = false;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Retention settings saved ✅'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2)));
            await Future.delayed(const Duration(seconds: 2));
            if (context.mounted) {
              ref.read(_saveStateProvider.notifier).state = _SaveState.idle;
            }
          }
        } catch (_) {
          if (context.mounted) {
            ref.read(_saveStateProvider.notifier).state = _SaveState.error;
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            gradient: state == _SaveState.saving
                ? null
                : const LinearGradient(colors: [
                    Color(0xFF10B981), Color(0xFF059669)]),
            color: state == _SaveState.saving ? const Color(0xFF1A1A1A) : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: state != _SaveState.saving
                ? [const BoxShadow(color: Color(0x4410B981),
                    blurRadius: 8, offset: Offset(0, 2))]
                : null),
        child: state == _SaveState.saving
            ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: Color(0xFF10B981), strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.save_rounded, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('Save', style: TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF080E14), Color(0xFF050A10), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 176',             const Color(0xFF3B82F6)),
          _badge('🟢/🟡 MIXED',             const Color(0xFF10B981)),
          _badge('Retention  ·  Day 1/3',   const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Data Retention\nSettings',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'DPDP §8 data minimisation — keep data only as long as needed. '
          'Set per-category expiry. Evidence vault timers. '
          'GPS purge schedule. Changes saved to Hive locally.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('7',      '7 categories',     Color(0xFF3B82F6)),
          _HStat('6',      'Configurable',     Color(0xFF10B981)),
          _HStat('1',      'Fixed (profile)',  Color(0xFF6B7280)),
          _HStat('§8',     'DPDP basis',       Color(0xFF8B5CF6)),
        ]),
      ]),
    );
  }

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.tune_rounded,       Color(0xFF3B82F6), 'Retention'),
      (Icons.lock_rounded,       Color(0xFFF59E0B), 'Evidence Vault'),
      (Icons.code_rounded,       Color(0xFF8B5CF6), 'API Contract'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1)),
          child: Column(children: [
            Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
            const SizedBox(height: ZapSpacing.xs),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Retention Settings
// ══════════════════════════════════════════════════════════════════════════════
class _RetentionTab extends ConsumerWidget {
  const _RetentionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings   = ref.watch(_retentionMapProvider);
    final expanded   = ref.watch(_expandedCatProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'DPDP §8: retain personal data only for as long as is necessary '
              'for the purpose for which it was collected. '
              'Changes are saved locally in Hive and synced to the server '
              'when backend implements PUT /api/v1/account/retention-settings.'),
      const SizedBox(height: ZapSpacing.lg),

      // Summary strip
      _SummaryStrip(settings: settings),
      const SizedBox(height: ZapSpacing.lg),

      // DPDP badge
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25))),
        child: const Row(children: [
          Icon(Icons.gavel_rounded, color: Color(0xFF8B5CF6), size: 14),
          SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(
            'DPDP Act 2023 §8: "A Data Fiduciary shall not retain personal data '
            'beyond the period necessary for the purpose for which the personal '
            'data was processed."',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10,
                height: 1.5, fontStyle: FontStyle.italic))),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('7 DATA CATEGORIES  ·  TAP TO CONFIGURE'),
      const SizedBox(height: ZapSpacing.md),

      ..._kCategories.map((cat) {
        final current = settings[cat.cat]!;
        final isFixed = cat.options.length == 1;
        final isExp   = expanded == cat.cat;

        return GestureDetector(
          onTap: isFixed ? null : () {
            ref.read(_expandedCatProvider.notifier).state =
                isExp ? null : cat.cat;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? cat.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? cat.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              // Header row
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(cat.icon, color: cat.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(cat.name, style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600))),
                      // Server vs local badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: (cat.serverEnforced
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981)).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          cat.serverEnforced ? '🟡' : '🟢',
                          style: const TextStyle(fontSize: 9))),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('Retention: ', style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                      Text(_periodLabel[current]!, style: TextStyle(
                          color: isFixed ? const Color(0xFF6B7280) : cat.color,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                      if (isFixed) ...[
                        const SizedBox(width: ZapSpacing.xs),
                        const Icon(Icons.lock_rounded,
                            color: Color(0xFF4B5563), size: 10),
                      ],
                    ]),
                  ])),
                  if (!isFixed)
                    Icon(isExp
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 16),
                ]),
              ),

              // Expanded: period picker + description + DPDP note
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // Description
                          Text(cat.description, style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
                          const SizedBox(height: ZapSpacing.md),

                          // Period picker
                          const _SectionLabel('RETENTION PERIOD'),
                          const SizedBox(height: ZapSpacing.sm),
                          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
                              children: cat.options.map((p) {
                            final isSelected = current == p;
                            return GestureDetector(
                              onTap: () {
                                final updated = Map<_RetCat, _RetPeriod>.from(
                                    ref.read(_retentionMapProvider));
                                updated[cat.cat] = p;
                                ref.read(_retentionMapProvider.notifier).state = updated;
                                ref.read(_dirtyProvider.notifier).state = true;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? cat.color.withOpacity(0.15)
                                        : const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isSelected
                                            ? cat.color.withOpacity(0.6)
                                            : const Color(0xFF2A2A2A),
                                        width: isSelected ? 2 : 1)),
                                child: Text(_periodLabel[p]!, style: TextStyle(
                                    color: isSelected ? cat.color : const Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700 : FontWeight.w400))));
                          }).toList()),
                          const SizedBox(height: ZapSpacing.md),

                          // DPDP note
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: cat.color.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: cat.color.withOpacity(0.2))),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.info_outline_rounded, color: cat.color, size: 12),
                              const SizedBox(width: 6),
                              Expanded(child: Text(cat.dpdpNote, style: const TextStyle(
                                  color: Color(0xFFD1D5DB), fontSize: 10, height: 1.5))),
                            ])),
                          const SizedBox(height: ZapSpacing.sm),

                          // Server vs local note
                          Row(children: [
                            Text(cat.serverEnforced ? '🟡' : '🟢', style: const TextStyle(fontSize: 10)),
                            const SizedBox(width: 5),
                            Text(
                              cat.serverEnforced
                                  ? 'MOCK-NOW — server enforcement pending (backend Day 78)'
                                  : 'FRONTEND-ONLY — stored in Hive, enforced locally',
                              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
                          ]),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),

      // Reset to defaults
      _outlineBtn(
        label: 'Reset all to defaults',
        color: const Color(0xFF6B7280),
        onTap: () {
          final defaults = Map.fromEntries(_kCategories.map((c) =>
              MapEntry(c.cat, c.defaultPeriod)));
          ref.read(_retentionMapProvider.notifier).state = defaults;
          ref.read(_dirtyProvider.notifier).state = true;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reset to ZapSafe recommended defaults'),
            backgroundColor: Color(0xFF1A1A1A),
            duration: Duration(seconds: 2)));
        },
      ),
    ]);
  }
}

class _SummaryStrip extends StatelessWidget {
  final Map<_RetCat, _RetPeriod> settings;
  const _SummaryStrip({required this.settings});

  @override
  Widget build(BuildContext context) {
    final shortestDays = settings.values
        .map((p) => _periodDays[p]!)
        .where((d) => d > 0)
        .fold(999, (a, b) => a < b ? a : b);
    final hasForevers = settings.values.any((p) => p == _RetPeriod.forever);
    final total = settings.length;
    final serverCount = _kCategories.where((c) => c.serverEnforced).length;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(children: [
        _stat('$total', 'Categories', const Color(0xFF3B82F6)),
        _stat('${shortestDays}d', 'Min retention', const Color(0xFF10B981)),
        _stat(hasForevers ? 'Yes' : 'No', 'Keep-forever', const Color(0xFFF59E0B)),
        _stat('$serverCount', 'Server-enforced', const Color(0xFF8B5CF6)),
      ]),
    );
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 8, height: 1.3),
        textAlign: TextAlign.center),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Evidence Vault Timer
// ══════════════════════════════════════════════════════════════════════════════
class _EvidenceVaultTab extends ConsumerWidget {
  const _EvidenceVaultTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedVaultProvider);
    final settings = ref.watch(_retentionMapProvider);
    final period   = settings[_RetCat.evidence]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.lock_rounded, color: const Color(0xFFF59E0B),
          text: 'Evidence vault files are the largest and most sensitive data. '
              'Each SOS event\'s vault has its own expiry countdown. '
              'Extend before expiry if you need the data for legal proceedings.'),
      const SizedBox(height: ZapSpacing.lg),

      // Current retention setting for evidence
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            const Text('Evidence Vault retention',
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(_periodLabel[period]!, style: const TextStyle(
                color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text('Each SOS event\'s evidence expires N days after the SOS date. '
              'Change in Tab 1 → Evidence Vault category.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
          if (period == _RetPeriod.forever) ...[
            const SizedBox(height: ZapSpacing.sm),
            const _WarningBanner(
                'Keep forever is set — evidence will not be auto-deleted. '
                'Manually delete from vault if no longer needed.'),
          ],
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Vault entries
      const _SectionLabel('3 EVIDENCE VAULT ENTRIES  ·  TAP TO MANAGE'),
      const SizedBox(height: ZapSpacing.md),

      ..._kVaultEntries.asMap().entries.map((e) {
        final i     = e.key;
        final entry = e.value;
        final isExp = expanded == i;
        final frac  = 1 - (entry.daysRemaining / entry.totalDays);
        final urgency = entry.daysRemaining <= 7
            ? const Color(0xFFEF4444)
            : entry.daysRemaining <= 30
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);

        return GestureDetector(
          onTap: () => ref.read(_expandedVaultProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? urgency.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? urgency.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  // Mini ring
                  SizedBox(
                    width: 44, height: 44,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                          value: frac,
                          backgroundColor: const Color(0xFF2A2A2A),
                          valueColor: AlwaysStoppedAnimation(urgency),
                          strokeWidth: 4),
                      Text('${entry.daysRemaining}',
                          style: TextStyle(color: urgency, fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ])),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.sosId, style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
                    Text('SOS on ${entry.date}  ·  ${entry.sizeMb} MB',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                    Text('${entry.daysRemaining} days remaining',
                        style: TextStyle(color: urgency, fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ])),
                  Icon(isExp
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              // Progress bar
              if (!isExp)
                Padding(
                  padding: const EdgeInsets.only(
                      left: ZapSpacing.md, right: ZapSpacing.md, bottom: ZapSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(urgency),
                        minHeight: 4))),

              // Expanded detail
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: _VaultEntryDetail(entry: entry, urgency: urgency))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.xl),

      // GPS purge schedule
      const _SectionLabel('GPS AUTO-PURGE SCHEDULE'),
      const SizedBox(height: ZapSpacing.md),
      _GpsPurgeCard(settings: settings),
    ]);
  }
}

class _VaultEntryDetail extends StatelessWidget {
  final _VaultEntry entry; final Color urgency;
  const _VaultEntryDetail({required this.entry, required this.urgency});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _kv('SOS ID',   entry.sosId),
          _kv('SOS date', entry.date),
          _kv('Files',    entry.files),
          _kv('Size',     '${entry.sizeMb} MB'),
          _kv('Expires',  '${entry.daysRemaining} of ${entry.totalDays} days remaining'),
        ])),
      const SizedBox(height: ZapSpacing.md),

      if (entry.daysRemaining <= 7)
        const _WarningBanner('⚠️ Expiring soon! Download before it\'s deleted.'),

      const SizedBox(height: ZapSpacing.sm),
      Row(children: [
        Expanded(child: _miniBtn('Extend 30 days', Icons.more_time_rounded,
            const Color(0xFF10B981), () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mock: extended ${entry.sosId} by 30 days'),
                    backgroundColor: const Color(0xFF10B981))))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: _miniBtn('Download', Icons.download_rounded,
            const Color(0xFF3B82F6), () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock: vault download started'),
                    backgroundColor: Color(0xFF3B82F6))))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: _miniBtn('Delete now', Icons.delete_rounded,
            const Color(0xFFEF4444), () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock: confirm deletion dialog would open'),
                    backgroundColor: Color(0xFFEF4444))))),
      ]),
    ]);
  }

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 72, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, fontFamily: 'monospace'))),
      ]));

  Widget _miniBtn(String l, IconData icon, Color c, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: c.withOpacity(0.35))),
            child: Column(children: [
              Icon(icon, color: c, size: 14),
              const SizedBox(height: 3),
              Text(l, style: TextStyle(color: c, fontSize: 9,
                  fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ])));
}

class _GpsPurgeCard extends StatelessWidget {
  final Map<_RetCat, _RetPeriod> settings;
  const _GpsPurgeCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final period = settings[_RetCat.location]!;
    final days   = _periodDays[period]!;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: ZapSpacing.sm),
          const Text('GPS History Auto-Purge', style: TextStyle(
              color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Every $days days', style: const TextStyle(
              color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        ...[
          ('Next purge', 'June ${13 + days - 14}, 2026  (in $days days)'),
          ('Scope', 'All GPS batches older than $days days'),
          ('Exception', 'GPS traces linked to active SOS events are exempt'),
          ('Runs at', '03:00 AM device local time (low-power window)'),
          ('Enforcement', '🟡 MOCK-NOW — backend job pending'),
        ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 84, child: Text(t.$1, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 10))),
                Expanded(child: Text(t.$2, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
              ]))),
      ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — API Contract
// ══════════════════════════════════════════════════════════════════════════════
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFF8B5CF6),
          text: 'Backend at Day 78. No retention-settings API yet. '
              'Replace _RetentionService.saveSettings() when backend is ready. '
              'Hive stores preferences locally in the meantime.'),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('ENDPOINT 1 — GET RETENTION SETTINGS'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// GET /api/v1/account/retention-settings
// Auth: Bearer JWT required
// Called on Settings → Data Retention screen load

// RESPONSE 200 OK
{
  "retention_settings": {
    "sos_events":    { "days": 365, "label": "1 year" },
    "evidence":      { "days": 90,  "label": "90 days" },
    "location":      { "days": 14,  "label": "14 days" },
    "analytics":     { "days": 30,  "label": "30 days" },
    "audit_log":     { "days": 90,  "label": "90 days" },
    "notifications": { "days": 30,  "label": "30 days" },
    "profile":       { "days": -1,  "label": "Keep forever" }
  },
  "last_updated": "2026-05-30T14:30:00Z"
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 2 — UPDATE RETENTION SETTINGS'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// PUT /api/v1/account/retention-settings
// Auth: Bearer JWT required
// DPDP §8: server enforces these as hard-delete schedules

// REQUEST
{
  "retention_settings": {
    "sos_events":    365,   // days; -1 = forever
    "evidence":      90,
    "location":      14,
    "analytics":     30,
    "audit_log":     90,
    "notifications": 30
    // "profile" cannot be set — always account-lifetime
  }
}

// RESPONSE 200 OK
{
  "updated": true,
  "next_purge_run": "2026-05-31T03:00:00Z",
  "message": "Settings saved. Purge scheduler updated."
}

// RESPONSE 422 — invalid period for category
{
  "error": "invalid_period",
  "field": "location",
  "message": "Location data cannot be retained longer than 90 days (DPDP §8 policy)"
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 3 — GET VAULT EXPIRY STATUS'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// GET /api/v1/evidence-vault/expiry
// Auth: Bearer JWT required
// Used by Evidence Vault tab to show per-SOS countdowns

// RESPONSE 200 OK
{
  "vault_entries": [
    {
      "sos_id": "sos_20260529",
      "sos_date": "2026-05-29",
      "days_remaining": 61,
      "retention_days": 90,
      "file_count": 6,
      "size_bytes": 26004889,
      "expires_at": "2026-08-27T00:00:00Z"
    }
  ]
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 4 — EXTEND VAULT EXPIRY'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// POST /api/v1/evidence-vault/{sos_id}/extend
// Auth: Bearer JWT required
// Used by "Extend 30 days" button in Evidence Vault tab

// REQUEST
{ "extend_days": 30 }

// RESPONSE 200 OK
{
  "sos_id": "sos_20260529",
  "new_expiry": "2026-09-26T00:00:00Z",
  "days_remaining": 91,
  "message": "Vault expiry extended by 30 days."
}

// RESPONSE 422 — would exceed max retention
{
  "error": "max_retention_exceeded",
  "max_days": 365,
  "message": "Evidence cannot be retained longer than 1 year."
}'''),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'Day 177 adds the auto-deletion scheduler preview: '
              '"What will be purged in the next 7 days" card + retention change history. '
              'Day 178 covers DPDP §8 edge cases and block sign-off.'),
    ]);
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _code(BuildContext context, String code) => GestureDetector(
    onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1))),
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

Widget _outlineBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)))));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner(this.text);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.warning_rounded, color: Color(0xFFF59E0B), size: 13),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFF59E0B), fontSize: 10, height: 1.4))),
      ]));
}
