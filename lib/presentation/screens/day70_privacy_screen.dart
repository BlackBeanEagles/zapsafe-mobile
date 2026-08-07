/// Day 70 — Privacy & Consent Screen
///
/// Two sections:
///   1. Privacy Settings — 3 opt-in toggles, each PATCH'd individually with
///      optimistic updates (flip immediately, revert on error).
///   2. Account Deletion — submit a GDPR right-to-erasure request, view its
///      current status, or cancel it (only while still PENDING).
///
/// All three privacy flags default to false (consent is strictly opt-in).
/// Deletion requests follow the lifecycle:
///   pending → acknowledged (admin) → completed (wiped)
/// Users can only cancel while still in PENDING status.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/privacy_service.dart';
import '../../domain/providers/privacy_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day70PrivacyScreen extends ConsumerStatefulWidget {
  const Day70PrivacyScreen({super.key});

  @override
  ConsumerState<Day70PrivacyScreen> createState() => _Day70PrivacyScreenState();
}

class _Day70PrivacyScreenState extends ConsumerState<Day70PrivacyScreen> {
  // ── Privacy settings state ────────────────────────────────────────────────
  PrivacySettings? _settings;
  bool _settingsSeeded = false;

  // per-flag saving flags and error
  bool    _savingAnalytics       = false;
  bool    _savingAutoArchive     = false;
  bool    _savingEvidence        = false;
  String? _settingsError;

  // ── Deletion request state ────────────────────────────────────────────────
  DeletionRequest? _deletion;
  bool _deletionSeeded = false;

  bool    _submitting = false;
  bool    _cancelling = false;
  String? _deletionError;

  // ─── Seed helpers ─────────────────────────────────────────────────────────

  void _seedSettings(PrivacySettings s) {
    if (_settingsSeeded) return;
    _settings = s;
    _settingsSeeded = true;
  }

  void _seedDeletion(DeletionRequest? d) {
    if (_deletionSeeded) return;
    _deletion = d;
    _deletionSeeded = true;
  }

  // ─── Toggle handler (optimistic) ──────────────────────────────────────────

  Future<void> _toggle(String field, bool newValue) async {
    if (_settings == null) return;

    final prev = _settings!;
    final next = switch (field) {
      'analytics'    => prev.copyWith(analyticsOptedIn: newValue),
      'autoArchive'  => prev.copyWith(autoArchiveDisabled: newValue),
      'evidence'     => prev.copyWith(evidenceCaptureConsent: newValue),
      _              => prev,
    };

    setState(() {
      _settings = next;
      _settingsError = null;
      if (field == 'analytics')   _savingAnalytics   = true;
      if (field == 'autoArchive') _savingAutoArchive = true;
      if (field == 'evidence')    _savingEvidence    = true;
    });

    try {
      final updated = await ref.read(privacyServiceProvider).patchSettings(
            analyticsOptedIn: field == 'analytics'   ? newValue : null,
            autoArchiveDisabled: field == 'autoArchive' ? newValue : null,
            evidenceCaptureConsent: field == 'evidence' ? newValue : null,
          );
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _settings = prev;
        _settingsError = 'Could not save — check your connection';
      });
    } finally {
      if (mounted) {
        setState(() {
          if (field == 'analytics')   _savingAnalytics   = false;
          if (field == 'autoArchive') _savingAutoArchive = false;
          if (field == 'evidence')    _savingEvidence    = false;
        });
      }
    }
  }

  // ─── Deletion handlers ────────────────────────────────────────────────────

  Future<void> _requestDeletion() async {
    final confirmed = await _showDeletionConfirmSheet();
    if (!mounted || confirmed == null) return;

    setState(() { _submitting = true; _deletionError = null; });
    try {
      final req = await ref.read(privacyServiceProvider).createDeletion(
            reason: confirmed.isEmpty ? null : confirmed,
          );
      if (!mounted) return;
      setState(() => _deletion = req);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletionError = 'Request failed — check your connection');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancelDeletion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        title: const Text('Cancel deletion request?',
            style: ZapTypography.headlineSmall),
        content: const Text(
          'Your account will remain active. '
          'You can submit a new request at any time.',
          style: ZapTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ZapColors.safe),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel it'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;

    setState(() { _cancelling = true; _deletionError = null; });
    try {
      await ref.read(privacyServiceProvider).cancelDeletion();
      if (!mounted) return;
      setState(() => _deletion = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletionError = 'Could not cancel — check your connection');
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Shows a bottom sheet asking for an optional reason; returns the reason
  /// string (may be empty) or null if the user dismissed.
  Future<String?> _showDeletionConfirmSheet() {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZapColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: ZapSpacing.lg,
          right: ZapSpacing.lg,
          top: ZapSpacing.md,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + ZapSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Warning icon + title
            const Row(
              children: [
                Icon(Icons.delete_forever_rounded,
                    size: 20, color: ZapColors.danger),
                SizedBox(width: ZapSpacing.sm),
                Text('Request Account Deletion',
                    style: ZapTypography.headlineSmall),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'This will permanently delete your account and all associated data. '
              'An admin will review and process the request within 30 days.',
              style: ZapTypography.bodySmall,
            ),
            const SizedBox(height: ZapSpacing.lg),
            Text('Reason (optional)',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary)),
            const SizedBox(height: ZapSpacing.xs),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 500,
              style: ZapTypography.bodySmall,
              decoration: InputDecoration(
                hintText: 'e.g. Switching to another app',
                hintStyle: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
                filled: true,
                fillColor: ZapColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(ZapSpacing.sm),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZapColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Submit Request'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(privacySettingsProvider);
    final deletionAsync = ref.watch(deletionRequestProvider);

    // seed once when data arrives
    settingsAsync.whenData(_seedSettings);
    deletionAsync.whenData(_seedDeletion);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Consent'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _settingsSeeded = false;
                _deletionSeeded  = false;
              });
              ref.invalidate(privacySettingsProvider);
              ref.invalidate(deletionRequestProvider);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          // ── Privacy Settings ───────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.shield_rounded,
            label: 'Privacy Settings',
            color: ZapColors.info,
          ),
          const SizedBox(height: ZapSpacing.sm),
          const _PrivacyInfoCard(),
          const SizedBox(height: ZapSpacing.sm),

          if (_settingsError != null) ...[
            _ErrorBanner(message: _settingsError!),
            const SizedBox(height: ZapSpacing.sm),
          ],

          settingsAsync.when(
            loading: () => _settings == null
                ? const _LoadingCard()
                : _SettingsCard(
                    settings: _settings!,
                    savingAnalytics:   _savingAnalytics,
                    savingAutoArchive: _savingAutoArchive,
                    savingEvidence:    _savingEvidence,
                    onToggle: _toggle,
                  ),
            error: (e, _) => _settings == null
                ? _ErrorBanner(message: e.toString())
                : _SettingsCard(
                    settings: _settings!,
                    savingAnalytics:   _savingAnalytics,
                    savingAutoArchive: _savingAutoArchive,
                    savingEvidence:    _savingEvidence,
                    onToggle: _toggle,
                  ),
            data: (_) => _SettingsCard(
              settings: _settings ?? PrivacySettings.defaults,
              savingAnalytics:   _savingAnalytics,
              savingAutoArchive: _savingAutoArchive,
              savingEvidence:    _savingEvidence,
              onToggle: _toggle,
            ),
          ),

          const SizedBox(height: ZapSpacing.xl),
          const Divider(color: ZapColors.bgElevated),
          const SizedBox(height: ZapSpacing.lg),

          // ── Account Deletion ───────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.delete_forever_rounded,
            label: 'Account Deletion',
            color: ZapColors.danger,
          ),
          const SizedBox(height: ZapSpacing.sm),
          const _DeletionInfoCard(),
          const SizedBox(height: ZapSpacing.sm),

          if (_deletionError != null) ...[
            _ErrorBanner(message: _deletionError!),
            const SizedBox(height: ZapSpacing.sm),
          ],

          deletionAsync.when(
            loading: () => _deletionSeeded
                ? _DeletionSection(
                    deletion:   _deletion,
                    submitting: _submitting,
                    cancelling: _cancelling,
                    onRequest:  _requestDeletion,
                    onCancel:   _cancelDeletion,
                  )
                : const _LoadingCard(),
            error: (e, _) => _deletionSeeded
                ? _DeletionSection(
                    deletion:   _deletion,
                    submitting: _submitting,
                    cancelling: _cancelling,
                    onRequest:  _requestDeletion,
                    onCancel:   _cancelDeletion,
                  )
                : _ErrorBanner(message: e.toString()),
            data: (_) => _DeletionSection(
              deletion:   _deletion,
              submitting: _submitting,
              cancelling: _cancelling,
              onRequest:  _requestDeletion,
              onCancel:   _cancelDeletion,
            ),
          ),

          const SizedBox(height: ZapSpacing.xl),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: ZapTypography.labelMedium.copyWith(color: color)),
      ],
    );
  }
}

// ─── Privacy Info Card ────────────────────────────────────────────────────────

class _PrivacyInfoCard extends StatelessWidget {
  const _PrivacyInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.info.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 13, color: ZapColors.info),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'All consent flags default to OFF. ZapSafe never shares data '
              'without your explicit opt-in.',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Settings Card (3 toggles) ────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.settings,
    required this.savingAnalytics,
    required this.savingAutoArchive,
    required this.savingEvidence,
    required this.onToggle,
  });

  final PrivacySettings settings;
  final bool savingAnalytics;
  final bool savingAutoArchive;
  final bool savingEvidence;
  final void Function(String field, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        children: [
          _ToggleRow(
            icon:        Icons.analytics_rounded,
            label:       'Analytics & Crash Reports',
            description: 'Help improve ZapSafe by sharing anonymous usage data',
            accent:      ZapColors.info,
            value:       settings.analyticsOptedIn,
            saving:      savingAnalytics,
            onChanged:   (v) => onToggle('analytics', v),
            isFirst:     true,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16,
              color: ZapColors.bgElevated),
          _ToggleRow(
            icon:        Icons.archive_outlined,
            label:       'Disable Auto-Archive',
            description: 'Keep SOS events from being automatically archived after 90 days',
            accent:      ZapColors.warning,
            value:       settings.autoArchiveDisabled,
            saving:      savingAutoArchive,
            onChanged:   (v) => onToggle('autoArchive', v),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16,
              color: ZapColors.bgElevated),
          _ToggleRow(
            icon:        Icons.mic_rounded,
            label:       'Evidence Capture Consent',
            description: 'Allow audio & photo capture during active SOS events',
            accent:      ZapColors.danger,
            value:       settings.evidenceCaptureConsent,
            saving:      savingEvidence,
            onChanged:   (v) => onToggle('evidence', v),
            isLast:      true,
          ),
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
    required this.description,
    required this.accent,
    required this.value,
    required this.saving,
    required this.onChanged,
    this.isFirst = false,
    this.isLast  = false,
  });

  final IconData  icon;
  final String    label;
  final String    description;
  final Color     accent;
  final bool      value;
  final bool      saving;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.md,
        isFirst ? ZapSpacing.md : ZapSpacing.sm,
        ZapSpacing.sm,
        isLast  ? ZapSpacing.md : ZapSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZapTypography.bodySmall),
                Text(description,
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          if (saving)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value:           value,
              onChanged:       onChanged,
              activeColor:     accent,
              activeTrackColor: accent.withOpacity(0.30),
            ),
        ],
      ),
    );
  }
}

// ─── Deletion Info Card ───────────────────────────────────────────────────────

class _DeletionInfoCard extends StatelessWidget {
  const _DeletionInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.danger.withOpacity(0.20)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: ZapColors.danger),
              SizedBox(width: 6),
              Text('GDPR Right to Erasure',
                  style: ZapTypography.labelSmall),
            ],
          ),
          SizedBox(height: ZapSpacing.xs),
          Text(
            'Submitting a deletion request notifies the ZapSafe admin team. '
            'Your data will be permanently wiped within 30 days. '
            'You may cancel the request while it is still PENDING.',
            style: ZapTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── Deletion Section ─────────────────────────────────────────────────────────

class _DeletionSection extends StatelessWidget {
  const _DeletionSection({
    required this.deletion,
    required this.submitting,
    required this.cancelling,
    required this.onRequest,
    required this.onCancel,
  });

  final DeletionRequest? deletion;
  final bool submitting;
  final bool cancelling;
  final VoidCallback onRequest;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (deletion == null) {
      // No active request — show submit button
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: submitting ? null : onRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: ZapColors.danger,
            side: const BorderSide(color: ZapColors.danger),
            minimumSize: const Size.fromHeight(48),
          ),
          icon: submitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ZapColors.danger))
              : const Icon(Icons.delete_forever_rounded),
          label: Text(submitting ? 'Submitting…' : 'Request Account Deletion'),
        ),
      );
    }

    // Active request card
    return _DeletionRequestCard(
      deletion:  deletion!,
      cancelling: cancelling,
      onCancel:   onCancel,
    );
  }
}

// ─── Deletion Request Card ────────────────────────────────────────────────────

class _DeletionRequestCard extends StatelessWidget {
  const _DeletionRequestCard({
    required this.deletion,
    required this.cancelling,
    required this.onCancel,
  });

  final DeletionRequest deletion;
  final bool            cancelling;
  final VoidCallback    onCancel;

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (deletion.status) {
      'pending'      => ('PENDING',      ZapColors.warning),
      'acknowledged' => ('ACKNOWLEDGED', ZapColors.info),
      'completed'    => ('COMPLETED',    ZapColors.safe),
      _              => (deletion.status.toUpperCase(), ZapColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: deletion.isPending
              ? ZapColors.warning.withOpacity(0.40)
              : ZapColors.bgElevated,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.delete_forever_rounded,
                  size: 16, color: ZapColors.danger),
              const SizedBox(width: 6),
              const Text('Deletion Request',
                  style: ZapTypography.labelMedium),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.30)),
                ),
                child: Text(statusLabel,
                    style: ZapTypography.labelSmall
                        .copyWith(color: statusColor)),
              ),
            ],
          ),

          const SizedBox(height: ZapSpacing.sm),
          const Divider(height: 1, color: ZapColors.bgElevated),
          const SizedBox(height: ZapSpacing.sm),

          // Submitted at
          _InfoRow(
            icon:  Icons.schedule_rounded,
            label: 'Submitted',
            value: _fmt(deletion.requestedAt),
          ),

          // Reason (if any)
          if (deletion.reason.isNotEmpty) ...[
            const SizedBox(height: ZapSpacing.xs),
            _InfoRow(
              icon:  Icons.chat_bubble_outline_rounded,
              label: 'Reason',
              value: deletion.reason,
            ),
          ],

          // Status description
          const SizedBox(height: ZapSpacing.sm),
          Text(
            switch (deletion.status) {
              'pending'      =>
                  'Your request is queued for admin review. '
                  'You may cancel it below.',
              'acknowledged' =>
                  'Your request has been acknowledged. A data wipe has been scheduled.',
              'completed'    =>
                  'Your account data has been permanently deleted.',
              _              => 'Status: ${deletion.status}',
            },
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary),
          ),

          // Cancel button — only while pending
          if (deletion.isCancellable) ...[
            const SizedBox(height: ZapSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: cancelling ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZapColors.safe,
                  side: const BorderSide(color: ZapColors.safe),
                ),
                icon: cancelling
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ZapColors.safe))
                    : const Icon(Icons.cancel_outlined, size: 16),
                label: Text(cancelling ? 'Cancelling…' : 'Cancel Deletion Request'),
              ),
            ),
          ],

          // Non-cancellable notice
          if (!deletion.isCancellable && deletion.status != 'completed') ...[
            const SizedBox(height: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: ZapColors.warning),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This request can no longer be cancelled — '
                      'the wipe has been scheduled.',
                      style: ZapTypography.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: ZapColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label  ',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary)),
        Expanded(
          child: Text(value, style: ZapTypography.labelSmall),
        ),
      ],
    );
  }
}

// ─── Loading card ─────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(ZapSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 14, color: ZapColors.danger),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(message,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.danger)),
          ),
        ],
      ),
    );
  }
}
