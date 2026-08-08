/// Day 67 — Notification Category Preferences Screen
///
/// Fine-grained per-category notification controls layered on top of the
/// existing global quiet-hours / caps settings (Days 28–30).
///
/// Five categories: SOS Alert · Check-in · Drill · AI Insight · Daily Digest
///
/// Each category card has three instant toggles:
///   • Push enabled
///   • SMS enabled
///   • Bypass quiet hours  (SOS Alert starts true by default)
///
/// Toggles fire a PATCH immediately — no save button.  Optimistic local
/// state gives instant feedback; on API error the toggle reverts and a
/// red banner appears.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/notification_pref_service.dart';
import '../../domain/providers/notification_pref_providers.dart';

// ─── Category metadata ────────────────────────────────────────────────────────

class _CatMeta {
  const _CatMeta(this.slug, this.label, this.description, this.icon, this.accent);
  final String slug;
  final String label;
  final String description;
  final IconData icon;
  final Color accent;
}

const _kCategories = [
  _CatMeta(
    'sos_alert', 'SOS Alert',
    'Live SOS dispatch to your emergency contacts',
    Icons.sos_rounded,
    ZapColors.danger,
  ),
  _CatMeta(
    'check_in', 'Check-in Alert',
    'Check-in timer expiry and overdue warnings',
    Icons.timer_rounded,
    ZapColors.warning,
  ),
  _CatMeta(
    'drill', 'Drill Mode',
    'Practice SOS completion and drill summaries',
    Icons.fitness_center_rounded,
    ZapColors.safe,
  ),
  _CatMeta(
    'insight', 'AI Insight',
    'ML-generated safety insights and anomaly alerts',
    Icons.psychology_rounded,
    ZapColors.info,
  ),
  _CatMeta(
    'digest', 'Daily Digest',
    'Daily summary of your protection score and events',
    Icons.summarize_rounded,
    ZapColors.textSecondary,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day67NotificationPrefScreen extends ConsumerStatefulWidget {
  const Day67NotificationPrefScreen({super.key});

  @override
  ConsumerState<Day67NotificationPrefScreen> createState() =>
      _Day67NotificationPrefScreenState();
}

class _Day67NotificationPrefScreenState
    extends ConsumerState<Day67NotificationPrefScreen> {
  // Local copy of prefs — optimistic updates applied here immediately.
  final Map<String, NotificationCategoryPref> _prefs = {};
  // Which categories are currently saving (PATCH in flight).
  final Map<String, bool> _saving = {};
  // Per-category error message.
  final Map<String, String?> _errors = {};
  // Whether local state has been seeded from the provider.
  bool _seeded = false;

  // ── Sync from provider (first load only) ──────────────────────────────────
  void _seedFromList(List<NotificationCategoryPref> list) {
    if (_seeded) return;
    for (final p in list) {
      _prefs[p.category] = p;
    }
    _seeded = true;
  }

  // ── Toggle handler ────────────────────────────────────────────────────────
  Future<void> _toggle(
    String category, {
    bool? pushEnabled,
    bool? smsEnabled,
    bool? bypassQuietHours,
  }) async {
    final current = _prefs[category];
    if (current == null) return;

    // Optimistic update.
    final optimistic = current.copyWith(
      pushEnabled:      pushEnabled,
      smsEnabled:       smsEnabled,
      bypassQuietHours: bypassQuietHours,
    );
    setState(() {
      _prefs[category]  = optimistic;
      _saving[category] = true;
      _errors[category] = null;
    });

    try {
      final updated = await ref
          .read(notificationPrefServiceProvider)
          .update(
            category,
            pushEnabled:      pushEnabled,
            smsEnabled:       smsEnabled,
            bypassQuietHours: bypassQuietHours,
          );
      if (!mounted) return;
      setState(() {
        _prefs[category]  = updated;
        _saving[category] = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Revert on error.
      setState(() {
        _prefs[category]  = current;
        _saving[category] = false;
        _errors[category] = 'Save failed — check your connection';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPrefListProvider);

    // Seed local state on first successful load.
    prefsAsync.whenData(_seedFromList);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _seeded = false);
              ref.invalidate(notificationPrefListProvider);
            },
          ),
        ],
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 48, color: ZapColors.danger),
                const SizedBox(height: ZapSpacing.md),
                Text('Failed to load preferences',
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.danger)),
                const SizedBox(height: ZapSpacing.sm),
                Text(e.toString(),
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: ZapSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _seeded = false);
                    ref.invalidate(notificationPrefListProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          children: [
            _InfoCard(),
            const SizedBox(height: ZapSpacing.lg),
            for (final meta in _kCategories) ...[
              _PrefCard(
                meta:   meta,
                pref:   _prefs[meta.slug],
                saving: _saving[meta.slug] ?? false,
                error:  _errors[meta.slug],
                onTogglePush:   (v) => _toggle(meta.slug, pushEnabled: v),
                onToggleSms:    (v) => _toggle(meta.slug, smsEnabled: v),
                onToggleBypass: (v) => _toggle(meta.slug, bypassQuietHours: v),
              ),
              const SizedBox(height: ZapSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.info.withOpacity(0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, size: 16, color: ZapColors.info),
          SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'These per-category controls layer on top of your global '
              'quiet-hours and notification caps. Toggles save instantly.',
              style: ZapTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pref Card ────────────────────────────────────────────────────────────────

class _PrefCard extends StatelessWidget {
  const _PrefCard({
    required this.meta,
    required this.pref,
    required this.saving,
    required this.error,
    required this.onTogglePush,
    required this.onToggleSms,
    required this.onToggleBypass,
  });

  final _CatMeta  meta;
  final NotificationCategoryPref? pref;
  final bool      saving;
  final String?   error;
  final ValueChanged<bool> onTogglePush;
  final ValueChanged<bool> onToggleSms;
  final ValueChanged<bool> onToggleBypass;

  @override
  Widget build(BuildContext context) {
    final push    = pref?.pushEnabled      ?? true;
    final sms     = pref?.smsEnabled       ?? true;
    final bypass  = pref?.bypassQuietHours ?? false;
    final isSos   = meta.slug == 'sos_alert';

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                ZapSpacing.md, ZapSpacing.md, ZapSpacing.md, ZapSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: meta.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(meta.icon, size: 18, color: meta.accent),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.label, style: ZapTypography.labelMedium),
                      Text(meta.description,
                          style: ZapTypography.bodySmall.copyWith(
                              color: ZapColors.textSecondary)),
                    ],
                  ),
                ),
                if (saving)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // ── Error banner ─────────────────────────────────────────────────
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 13, color: ZapColors.danger),
                    const SizedBox(width: ZapSpacing.xs),
                    Expanded(
                      child: Text(error!,
                          style: ZapTypography.labelSmall.copyWith(
                              color: ZapColors.danger)),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1, color: ZapColors.bgElevated,
              indent: ZapSpacing.md, endIndent: ZapSpacing.md),

          // ── Toggle rows ──────────────────────────────────────────────────
          _ToggleRow(
            icon:    Icons.notifications_rounded,
            label:   'Push notifications',
            value:   push,
            saving:  saving,
            onChanged: onTogglePush,
          ),
          _ToggleRow(
            icon:    Icons.sms_rounded,
            label:   'SMS notifications',
            value:   sms,
            saving:  saving,
            onChanged: onToggleSms,
          ),
          _ToggleRow(
            icon:    Icons.do_not_disturb_off_rounded,
            label:   'Bypass quiet hours',
            value:   bypass,
            saving:  saving,
            onChanged: onToggleBypass,
            accentOn: isSos ? ZapColors.warning : null,
            hint: isSos
                ? 'SOS alerts bypass quiet windows by default'
                : 'Send even during your quiet-hours window',
          ),

          const SizedBox(height: ZapSpacing.xs),
        ],
      ),
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.saving,
    required this.onChanged,
    this.accentOn,
    this.hint,
  });

  final IconData  icon;
  final String    label;
  final bool      value;
  final bool      saving;
  final ValueChanged<bool> onChanged;
  final Color?    accentOn;  // non-null → use this color when value == true
  final String?   hint;

  @override
  Widget build(BuildContext context) {
    final trackColor = accentOn != null && value
        ? accentOn!.withOpacity(0.5)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: ZapColors.textSecondary),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZapTypography.bodySmall),
                if (hint != null)
                  Text(hint!,
                      style: ZapTypography.labelSmall.copyWith(
                          color: ZapColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: saving ? null : onChanged,
            activeTrackColor: trackColor,
          ),
        ],
      ),
    );
  }
}
