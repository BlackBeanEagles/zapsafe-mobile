/// Day 82 — Evidence Vault Screen
///
/// Forensic chain-of-custody browser for all SOS evidence.
///
/// ── LP16 — Vault PIN ─────────────────────────────────────────────────────────
///   Separate 4-digit PIN from the SOS cancel/duress PIN (LP3).
///   DEV badge shown when no PIN is stored; fallback: 1234.
///
/// ── LP23 — Cascade wipe ──────────────────────────────────────────────────────
///   3 wrong PINs → key-rotation warning banner.
///   5 wrong PINs → vault wiped (files purged, PIN cleared).
///   In emulator dev mode the cascade resets on app restart.
///
/// ── File browser (unlocked state) ────────────────────────────────────────────
///   • Per-event cards: SOS ID, timestamp, location, trigger type, tamper flag
///   • Expandable: 6 forensic streams per event
///   • Each stream: type icon, file name, size, duration, SHA-256 hash preview,
///     integrity badge (✓ Verified / ✕ Tampered)
///   • Expiry countdown with extend option
///   • Export bottom sheet: encrypted ZIP or legal PDF (mock)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/vault_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day82EvidenceVaultScreen extends ConsumerWidget {
  const Day82EvidenceVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(vaultLockedProvider);
    final wiped  = ref.watch(vaultWipedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:  ZapColors.bgPrimary,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: ZapColors.textPrimary),
        title: Text(
          'Evidence Vault',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        actions: [
          if (!locked && !wiped)
            IconButton(
              icon:    const Icon(Icons.lock_outline_rounded, color: ZapColors.textSecondary),
              tooltip: 'Lock vault',
              onPressed: () {
                ref.read(vaultLockedProvider.notifier).state = true;
                ref.read(vaultWrongPinCountProvider.notifier).state = 0;
              },
            ),
        ],
      ),
      body: wiped
          ? const _WipedView()
          : locked
              ? const _PinGate()
              : const _VaultBrowser(),
    );
  }
}

// ─── Wiped view (LP23 — 5 wrong PINs) ───────────────────────────────────────

class _WipedView extends StatelessWidget {
  const _WipedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  72, height: 72,
              decoration: BoxDecoration(
                color:        ZapColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                size:  36,
                color: ZapColors.danger,
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),
            Text(
              'Vault wiped',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.danger, fontFamily: 'ClashDisplay',
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'Too many incorrect PINs. All evidence files have been '
              'securely deleted per LP23 cascade policy.',
              textAlign: TextAlign.center,
              style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textSecondary, height: 1.5,
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),
            Text(
              'Contact support to restore access.',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PIN gate (LP16 / LP23) ───────────────────────────────────────────────────

class _PinGate extends ConsumerStatefulWidget {
  const _PinGate();

  @override
  ConsumerState<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends ConsumerState<_PinGate>
    with SingleTickerProviderStateMixin {

  final List<int> _pin = [];
  bool _error = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end:  8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end:  0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(int d) {
    if (_pin.length >= 4) return;
    setState(() => _pin.add(d));
    HapticFeedback.selectionClick();
    if (_pin.length == 4) _validate();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
    HapticFeedback.selectionClick();
  }

  void _validate() {
    final entered = _pin.join();
    if (entered == kVaultDevPin) {
      ref.read(vaultLockedProvider.notifier).state = false;
      ref.read(vaultWrongPinCountProvider.notifier).state = 0;
    } else {
      final count = ref.read(vaultWrongPinCountProvider) + 1;
      ref.read(vaultWrongPinCountProvider.notifier).state = count;
      if (count >= 5) {
        ref.read(vaultWipedProvider.notifier).state = true;
        return;
      }
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0.0);
      setState(() => _error = true);
      Future<void>.delayed(const Duration(milliseconds: 560)).then((_) {
        if (mounted) setState(() { _error = false; _pin.clear(); });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wrongCount = ref.watch(vaultWrongPinCountProvider);

    return Column(
      children: [
        // ── LP23 warning banner ───────────────────────────────────────────
        if (wrongCount >= 3)
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm,
            ),
            color: ZapColors.danger.withOpacity(0.12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: ZapColors.danger, size: 16),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    wrongCount >= 4
                        ? 'Last attempt before vault wipe (LP23)'
                        : 'Key rotation triggered — ${5 - wrongCount} attempt(s) left before wipe',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
                  ),
                ),
              ],
            ),
          ),

        // ── Lock icon + title ─────────────────────────────────────────────
        const Spacer(),
        Container(
          width:  64, height: 64,
          decoration: BoxDecoration(
            color:        ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.lock_rounded, size: 30, color: ZapColors.safe),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Vault PIN',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary, fontFamily: 'ClashDisplay',
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Enter your vault PIN to access evidence files',
          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
          textAlign: TextAlign.center,
        ),

        // DEV badge
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 3,
          ),
          decoration: BoxDecoration(
            color:        ZapColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border:       Border.all(color: ZapColors.warning.withOpacity(0.4)),
          ),
          child: Text(
            'DEV  PIN: $kVaultDevPin',
            style: TextStyle(
              fontSize:   10,
              color:      ZapColors.warning.withOpacity(0.8),
              fontFamily: 'IBMPlexMono',
            ),
          ),
        ),

        const SizedBox(height: ZapSpacing.xxxl),

        // ── PIN dots ──────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child:  child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              final Color dotColor;
              if (_error && filled) {
                dotColor = ZapColors.danger;
              } else if (filled) {
                dotColor = ZapColors.safe;
              } else {
                dotColor = ZapColors.bgSurface;
              }
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width:  14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(
                    color: filled ? Colors.transparent : ZapColors.border,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: ZapSpacing.xxxl),

        // ── PIN pad ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.xxxl),
          child: _PinPad(onDigit: _onDigit, onDelete: _onDelete),
        ),
        const Spacer(),
      ],
    );
  }
}

// ─── PIN pad ──────────────────────────────────────────────────────────────────

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onDelete});
  final ValueChanged<int> onDigit;
  final VoidCallback      onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(digits: const [1, 2, 3], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.lg),
        _Row(digits: const [4, 5, 6], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.lg),
        _Row(digits: const [7, 8, 9], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 64),
            _DigitKey(digit: 0, onDigit: onDigit),
            GestureDetector(
              onTap: onDelete,
              child: const SizedBox(
                width: 64, height: 64,
                child: Icon(Icons.backspace_outlined, color: Colors.white38, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.digits, required this.onDigit});
  final List<int>         digits;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _DigitKey(digit: d, onDigit: onDigit)).toList(),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onDigit});
  final int               digit;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onDigit(digit),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: const TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize:   26,
            fontWeight: FontWeight.w500,
            color:      Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Vault browser (unlocked) ─────────────────────────────────────────────────

class _VaultBrowser extends ConsumerStatefulWidget {
  const _VaultBrowser();

  @override
  ConsumerState<_VaultBrowser> createState() => _VaultBrowserState();
}

class _VaultBrowserState extends ConsumerState<_VaultBrowser> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vaultEvidenceProvider);

    return entries.isEmpty
        ? _emptyVault()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.lg,
              vertical:   ZapSpacing.md,
            ),
            itemCount:   entries.length,
            itemBuilder: (_, i) => _EntryCard(
              entry:      entries[i],
              isExpanded: _expanded.contains(entries[i].sosId),
              onToggle:   () => setState(() {
                if (_expanded.contains(entries[i].sosId)) {
                  _expanded.remove(entries[i].sosId);
                } else {
                  _expanded.add(entries[i].sosId);
                }
              }),
              onExport:   () => _showExportSheet(context, entries[i]),
              onExtend:   () => _showExtendSnack(context, entries[i]),
            ),
          );
  }

  Widget _emptyVault() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 48, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'No evidence files',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Evidence is stored automatically\nwhen an SOS event occurs.',
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportSheet(BuildContext context, EvidenceEntry entry) {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: ZapColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExportSheet(entry: entry),
    );
  }

  void _showExtendSnack(BuildContext context, EvidenceEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZapColors.bgElevated,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          'Extension requested for ${entry.sosId}',
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
        ),
        action: SnackBarAction(
          label:     'OK',
          textColor: ZapColors.safe,
          onPressed: () {},
        ),
      ),
    );
  }
}

// ─── Entry card ───────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.isExpanded,
    required this.onToggle,
    required this.onExport,
    required this.onExtend,
  });

  final EvidenceEntry entry;
  final bool          isExpanded;
  final VoidCallback  onToggle;
  final VoidCallback  onExport;
  final VoidCallback  onExtend;

  String _formatTime(DateTime dt) {
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final expiryColor = entry.daysUntilExpiry <= 3
        ? ZapColors.danger
        : entry.daysUntilExpiry <= 10
            ? ZapColors.warning
            : ZapColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.hasTamperFlag
              ? ZapColors.danger.withOpacity(0.5)
              : ZapColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          InkWell(
            onTap:        onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // SOS ID
                      Expanded(
                        child: Text(
                          entry.sosId,
                          style: ZapTypography.labelMedium.copyWith(
                            color:      ZapColors.textPrimary,
                            fontFamily: 'IBMPlexMono',
                          ),
                        ),
                      ),
                      // Tamper badge
                      if (entry.hasTamperFlag)
                        Container(
                          margin:  const EdgeInsets.only(right: ZapSpacing.sm),
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZapSpacing.sm, vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:        ZapColors.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_rounded,
                                  size: 10, color: ZapColors.danger),
                              const SizedBox(width: 3),
                              Text(
                                'TAMPERED',
                                style: ZapTypography.labelSmall.copyWith(
                                  color:     ZapColors.danger,
                                  fontSize:  9,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Expand chevron
                      AnimatedRotation(
                        turns:    isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: ZapColors.textMuted,
                          size:  20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: ZapColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(entry.timestamp),
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary, fontFamily: 'IBMPlexMono',
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: ZapColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.locationLabel,
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.sensors_rounded,
                          size: 12, color: ZapColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        entry.triggerType,
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      // Expiry
                      GestureDetector(
                        onTap: onExtend,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_bottom_rounded,
                                size: 12, color: expiryColor),
                            const SizedBox(width: 3),
                            Text(
                              '${entry.daysUntilExpiry}d left',
                              style: ZapTypography.labelSmall.copyWith(
                                color:   expiryColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.add_circle_outline_rounded,
                                size: 11, color: expiryColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded file list ─────────────────────────────────────────
          if (isExpanded) ...[
            const Divider(color: ZapColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                children: [
                  ...entry.files.map(
                    (f) => _FileRow(file: f),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  // Export button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.output_rounded, size: 16),
                      label: const Text('Export evidence'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ZapColors.safe,
                        side: const BorderSide(color: ZapColors.safe, width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

// ─── File row ─────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});
  final EvidenceFile file;

  IconData get _icon {
    switch (file.type) {
      case EvidenceFileType.audio:      return Icons.graphic_eq_rounded;
      case EvidenceFileType.videoFront: return Icons.videocam_rounded;
      case EvidenceFileType.videoRear:  return Icons.video_camera_back_rounded;
      case EvidenceFileType.imu:        return Icons.speed_rounded;
      case EvidenceFileType.gps:        return Icons.location_on_rounded;
      case EvidenceFileType.dcsLog:     return Icons.description_outlined;
    }
  }

  Color get _accent {
    switch (file.type) {
      case EvidenceFileType.audio:      return ZapColors.danger;
      case EvidenceFileType.videoFront: return ZapColors.info;
      case EvidenceFileType.videoRear:  return ZapColors.info;
      case EvidenceFileType.imu:        return ZapColors.warning;
      case EvidenceFileType.gps:        return ZapColors.safe;
      case EvidenceFileType.dcsLog:     return ZapColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          // Type icon
          Container(
            width:  32, height: 32,
            decoration: BoxDecoration(
              color:        _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 15, color: _accent),
          ),
          const SizedBox(width: ZapSpacing.sm),

          // Name + hash
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${file.type.label}${file.type.ext}',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      file.hashPreview,
                      style: ZapTypography.labelSmall.copyWith(
                        color:      ZapColors.textMuted,
                        fontFamily: 'IBMPlexMono',
                        fontSize:   9,
                      ),
                    ),
                    if (file.durationLabel != null) ...[
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        '·  ${file.durationLabel}',
                        style: ZapTypography.labelSmall.copyWith(
                          color:   ZapColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Size
          Text(
            file.sizeLabel,
            style: ZapTypography.labelSmall.copyWith(
              color:      ZapColors.textSecondary,
              fontFamily: 'IBMPlexMono',
              fontSize:   10,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),

          // Integrity badge
          if (file.isTampered)
            const _IntegrityBadge(verified: false)
          else
            const _IntegrityBadge(verified: true),
        ],
      ),
    );
  }
}

class _IntegrityBadge extends StatelessWidget {
  const _IntegrityBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? ZapColors.safe : ZapColors.danger;
    final icon  = verified ? Icons.verified_rounded : Icons.gpp_bad_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            verified ? 'OK' : 'FAIL',
            style: ZapTypography.labelSmall.copyWith(
              color:     color,
              fontSize:  9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export bottom sheet ──────────────────────────────────────────────────────

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.entry});
  final EvidenceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        ZapColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'Export — ${entry.sosId}',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Choose export format. Files are encrypted with AES-256.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary, height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          _ExportOption(
            icon:     Icons.folder_zip_outlined,
            accent:   ZapColors.info,
            title:    'Encrypted ZIP',
            subtitle: 'All 6 streams + chain-of-custody manifest\nFor police submission',
            onTap:    () {
              Navigator.pop(context);
              _snack(context, 'Encrypted ZIP prepared — link expires in 24h');
            },
          ),
          const SizedBox(height: ZapSpacing.md),

          _ExportOption(
            icon:     Icons.picture_as_pdf_outlined,
            accent:   ZapColors.warning,
            title:    'Legal PDF',
            subtitle: 'Signed affidavit with hash table\nFor court submission',
            onTap:    () {
              Navigator.pop(context);
              _snack(context, 'Legal PDF generated — check your email');
            },
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZapColors.bgElevated,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          msg,
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData     icon;
  final Color        accent;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color:        ZapColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width:  40, height: 40,
              decoration: BoxDecoration(
                color:        accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary, height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: ZapColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
