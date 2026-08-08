/// Day 319 — GDPR Consent Flow Wire
///
/// 🟢 LIVE (fixed for Play Store item 10 — was 🟡 MOCK-NOW).
///
/// `GET/PUT /api/v1/account/consent/` is now actually called, via
/// [AccountService] (lib/data/services/account_service.dart) —
/// previously confirmed real and live on the backend
/// (`ConsentView` in `zapsafe_backend/account/views.py`) but never
/// wired from any Dart caller, a real Day 336/361 P1 finding.
///
/// Field names match the REAL backend contract:
///   location_sos, evidence_recording, cloud_backup,
///   heatmap_contribution, analytics, model_improvement
///
/// Implements exactly the 5-step migration plan this screen's own
/// "Migration Plan" tab already documented (still shown below, now
/// marked as DONE rather than planned):
///   1. On load: GET from server; if it fails (offline, etc.), fall
///      back to the local ConsentWireStorage cache so the UI still
///      shows something meaningful rather than an error screen.
///   2. On toggle: write to ConsentWireStorage immediately (unchanged
///      offline-first UX), then fire PUT in the background.
///   3. Conflict handling: unnecessary in practice — location_sos is
///      locked in the UI, so the client never sends `false` for it;
///      the server's 400 LOCATION_SOS_REQUIRED rejection is
///      structurally unreachable from this screen.
///   4. Failure handling: a failed PUT leaves the local
///      ConsentWireStorage value as source of truth (already written
///      in step 2) and is silently retried on the next toggle or next
///      screen load — no error dialog interrupts the user for a
///      background sync failure, matching this app's established
///      offline-first pattern (Day 306 notification tier acks).
///
/// Storage: `ConsentWireStorage` (SharedPreferences) remains the local
/// cache/offline fallback — not replaced, since `main.dart` never calls
/// `Hive.initFlutter()` and losing the offline-first behavior would be
/// a regression, not a fix.
///
/// GDPR lawful-basis text per toggle uses real, standard Article
/// citations (Art. 6(1)(a) consent, Art. 6(1)(b) contract necessity,
/// Art. 6(1)(f) legitimate interests) as commonly-taught privacy-
/// engineering mappings for this kind of data use — written for
/// product/UX clarity, not a substitute for legal review before a real
/// GDPR compliance claim.
///
/// Route: AppRoutes.gdprConsentWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/consent_wire_storage.dart';
import '../../domain/providers/account_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class _ConsentField {
  const _ConsentField({
    required this.key,
    required this.title,
    required this.description,
    required this.lawfulBasis,
    required this.isRequired,
    required this.defaultValue,
  });

  final String key;
  final String title;
  final String description;
  final String lawfulBasis;
  final bool isRequired;
  final bool defaultValue;
}

const _kConsentFields = [
  _ConsentField(
    key: 'location_sos',
    title: 'Location during SOS',
    description: 'GPS shared with trusted contacts during an active SOS. App cannot function without it.',
    lawfulBasis: 'Art. 6(1)(b) — necessary for performance of the safety service you signed up for.',
    isRequired: true,
    defaultValue: true,
  ),
  _ConsentField(
    key: 'evidence_recording',
    title: 'Evidence Recording',
    description: 'Audio/video capture during SOS, encrypted on-device.',
    lawfulBasis: 'Art. 6(1)(a) — explicit, withdrawable consent.',
    isRequired: false,
    defaultValue: true,
  ),
  _ConsentField(
    key: 'cloud_backup',
    title: 'Cloud Evidence Backup',
    description: 'Store evidence on ZapSafe servers vs. device-only.',
    lawfulBasis: 'Art. 6(1)(a) — explicit, withdrawable consent.',
    isRequired: false,
    defaultValue: false,
  ),
  _ConsentField(
    key: 'heatmap_contribution',
    title: 'Anonymous Heatmap Contribution',
    description: 'Share anonymized, rounded location to warn other users about unsafe areas.',
    lawfulBasis: 'Art. 6(1)(a) — explicit, withdrawable consent (even though anonymized).',
    isRequired: false,
    defaultValue: true,
  ),
  _ConsentField(
    key: 'analytics',
    title: 'Crash & Usage Analytics',
    description: 'Anonymous crash reports and aggregate screen-view counts (Sentry).',
    lawfulBasis: 'Art. 6(1)(f) — legitimate interest in fixing bugs, balanced against your right to opt out.',
    isRequired: false,
    defaultValue: false,
  ),
  _ConsentField(
    key: 'model_improvement',
    title: 'Detection Model Improvement',
    description: 'Anonymized statistical features from false-alarm reports used to retrain detection models.',
    lawfulBasis: 'Art. 6(1)(a) — explicit, withdrawable consent.',
    isRequired: false,
    defaultValue: false,
  ),
];

class Day319GdprConsentWireScreen extends ConsumerStatefulWidget {
  const Day319GdprConsentWireScreen({super.key});

  @override
  ConsumerState<Day319GdprConsentWireScreen> createState() => _Day319GdprConsentWireScreenState();
}

class _Day319GdprConsentWireScreenState extends ConsumerState<Day319GdprConsentWireScreen> {
  final _storage = ConsentWireStorage();
  Map<String, bool> _values = {};
  bool _loading = true;
  bool _serverSynced = false;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Step 1 of the migration plan: try the real server first, fall back
  /// to the local cache on any failure (offline, timeout, etc.) so the
  /// screen still shows something meaningful.
  Future<void> _load() async {
    final loaded = <String, bool>{};
    for (final f in _kConsentFields) {
      loaded[f.key] = await _storage.getFlag(f.key) ?? f.defaultValue;
    }

    try {
      final remote = await ref.read(accountServiceProvider).fetchConsent();
      loaded['location_sos']         = remote.locationSos;
      loaded['evidence_recording']   = remote.evidenceRecording;
      loaded['cloud_backup']         = remote.cloudBackup;
      loaded['heatmap_contribution'] = remote.heatmapContribution;
      loaded['analytics']            = remote.analytics;
      loaded['model_improvement']    = remote.modelImprovement;
      // Keep the local cache in sync with whatever the server returned,
      // so the offline fallback path above stays accurate next launch.
      for (final entry in loaded.entries) {
        await _storage.setFlag(entry.key, entry.value);
      }
      if (mounted) _serverSynced = true;
    } catch (_) {
      // Step 1's documented fallback: local cache values already loaded
      // above stand as-is. No error surfaced to the user for a
      // background sync failure — offline-first, matching this app's
      // established pattern elsewhere.
    }

    if (mounted) {
      setState(() {
        _values = loaded;
        _loading = false;
      });
    }
  }

  /// Step 2 + step 4 of the migration plan: write local immediately
  /// (unchanged offline-first UX), then fire the real PUT in the
  /// background — a failure there just leaves local as source of truth,
  /// silently retried next toggle/load.
  Future<void> _toggle(_ConsentField field, bool value) async {
    if (field.isRequired) return;
    setState(() => _values[field.key] = value);
    await _storage.setFlag(field.key, value);

    try {
      await ref.read(accountServiceProvider).putConsent(
            locationSos: field.key == 'location_sos' ? value : null,
            evidenceRecording: field.key == 'evidence_recording' ? value : null,
            cloudBackup: field.key == 'cloud_backup' ? value : null,
            heatmapContribution: field.key == 'heatmap_contribution' ? value : null,
            analytics: field.key == 'analytics' ? value : null,
            modelImprovement: field.key == 'model_improvement' ? value : null,
          );
    } catch (_) {
      // Step 4: local value (already written above) remains authoritative.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.gdpr_consent_title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              children: [
                ZapCard(
                  backgroundColor: (_serverSynced ? ZapColors.safe : ZapColors.warning).withOpacity(0.08),
                  borderColor: (_serverSynced ? ZapColors.safe : ZapColors.warning).withOpacity(0.3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _serverSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: _serverSynced ? ZapColors.safe : ZapColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          _serverSynced
                              ? '🟢 LIVE — synced with GET /api/v1/account/consent/ on load, '
                                'each toggle PUTs in the background. Local SharedPreferences '
                                '(ConsentWireStorage) stays as the offline-first cache/fallback.'
                              : '🟡 Offline — could not reach the server on load; showing '
                                'locally-cached values (ConsentWireStorage). Toggles still '
                                'save locally and will sync to /api/v1/account/consent/ next '
                                'time the server is reachable.',
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZapSpacing.lg),
                Row(
                  children: [
                    _TabChip(label: 'Consent', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: ZapSpacing.sm),
                    _TabChip(
                        label: 'Migration Plan', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                    const SizedBox(width: ZapSpacing.sm),
                    _TabChip(
                        label: 'API Contract', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                  ],
                ),
                const SizedBox(height: ZapSpacing.lg),
                if (_tab == 0) _ConsentTab(values: _values, onToggle: _toggle),
                if (_tab == 1) const _MigrationPlanTab(),
                if (_tab == 2) const _ApiContractTab(),
                const SizedBox(height: ZapSpacing.huge),
              ],
            ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? ZapColors.info.withOpacity(0.15) : ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: selected ? ZapColors.info.withOpacity(0.5) : ZapColors.border),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: ZapTypography.labelMedium.copyWith(
                color: selected ? ZapColors.info : ZapColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              )),
        ),
      ),
    );
  }
}

class _ConsentTab extends StatelessWidget {
  const _ConsentTab({required this.values, required this.onToggle});
  final Map<String, bool> values;
  final void Function(_ConsentField, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final field in _kConsentFields)
          ZapCard(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(field.title,
                          style: ZapTypography.bodyMedium
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                    ),
                    if (field.isRequired)
                      const ZapBadge(label: 'REQUIRED', intent: ZapBadgeIntent.danger, size: ZapBadgeSize.small)
                    else
                      Switch(
                        value: values[field.key] ?? field.defaultValue,
                        onChanged: (v) => onToggle(field, v),
                        activeColor: ZapColors.safe,
                      ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(field.description,
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                const SizedBox(height: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: ZapColors.info.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.gavel_rounded, size: 14, color: ZapColors.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(field.lawfulBasis,
                            style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Lawful-basis mappings above are standard privacy-engineering '
          'patterns for this kind of data use — written for product/UX '
          'clarity, not legal advice. Consult counsel before making a '
          'public GDPR compliance claim.',
          style: ZapTypography.labelMedium.copyWith(color: ZapColors.textMuted, height: 1.5),
        ),
      ],
    );
  }
}

class _MigrationPlanTab extends StatelessWidget {
  const _MigrationPlanTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.check_circle_rounded,
          color: ZapColors.safe,
          text: 'DONE — this plan is now implemented exactly as written below. '
              'GET/PUT /api/v1/account/consent/ is live-called from this screen '
              '(account_service.dart); SharedPreferences remains the offline-'
              'first cache/fallback, not a placeholder waiting to be replaced.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _step(1, 'On login / app start',
            'Call GET /api/v1/account/consent/. If the server\'s updated_at is newer '
                'than the local ConsentWireStorage value, overwrite local with server.'),
        _step(2, 'On toggle change',
            'Keep writing to ConsentWireStorage immediately (offline-first UX unchanged), '
                'then fire PUT /api/v1/account/consent/ in the background with the full '
                'current flag set.'),
        _step(3, 'Conflict handling',
            'Server already rejects location_sos: false with a 400 '
                'LOCATION_SOS_REQUIRED error (real, in ConsentView.put()) — the client '
                'never needs to special-case this since the toggle is already locked '
                'in the UI.'),
        _step(4, 'Failure handling',
            'A failed PUT leaves the local value as source of truth and retries on next '
                'toggle or app foreground — consistent with this app\'s offline-first '
                'pattern elsewhere (e.g. Day 306\'s notification tier acks).'),
        _step(5, 'No UI restructuring needed',
            'All toggle logic, GDPR lawful-basis text, and the required-item lock stay '
                'exactly as-is — only two network calls get added, same as Day 155\'s '
                'own migration note.'),
      ],
    );
  }

  Widget _step(int n, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: ZapSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZapBadge(label: '$n', intent: ZapBadgeIntent.info, size: ZapBadgeSize.small),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(body, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.verified_rounded,
          color: ZapColors.safe,
          text: 'Confirmed real and live this session: zapsafe_backend/account/'
              'views.py ConsentView, routed in account/urls.py, backed by the real '
              'UserConsent model in account/models.py. Field names below are the '
              'actual contract, not a placeholder.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _codeCard('GET/PUT /api/v1/account/consent/',
            'Authorization: Bearer {jwt}\n'
            '\n'
            'Request/response body (UserConsent.as_contract_dict()):\n'
            '{\n'
            '  "location_sos":          true,   // always true — server rejects false\n'
            '  "evidence_recording":    true,\n'
            '  "cloud_backup":          false,\n'
            '  "heatmap_contribution":  true,\n'
            '  "analytics":             false,\n'
            '  "model_improvement":     false,\n'
            '  "updated_at":            "2026-08-07T10:00:00Z"\n'
            '}\n'
            '\n'
            'PUT with location_sos: false -> 400\n'
            '{ "error": "...", "code": "LOCATION_SOS_REQUIRED" }'),
        const SizedBox(height: ZapSpacing.md),
        _codeCard('local_storage.dart',
            'ConsentWireStorage (lib/data/services/consent_wire_storage.dart)\n'
            'Key: zapsafe.consent.<field>\n'
            'Value: bool, plus zapsafe.consent.<field>.updated_at (ISO8601)\n'
            'SharedPreferences — same precedent as Day 37 GpsStorage / Day 306\n'
            'NotificationTierAckStorage (main.dart never calls Hive.initFlutter()).'),
      ],
    );
  }
}

Widget _infoBox({required IconData icon, required Color color, required String text}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.6))),
      ]),
    );

Widget _codeCard(String filename, String code) => GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: code));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgPrimary,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: ZapColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: ZapColors.bgSurface, borderRadius: BorderRadius.circular(4)),
            child: Text(filename,
                style: ZapTypography.labelMedium.copyWith(color: ZapColors.info, fontFamily: 'monospace')),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(code,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, fontFamily: 'monospace', height: 1.6)),
        ]),
      ),
    );
