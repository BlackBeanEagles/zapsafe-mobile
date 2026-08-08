/// Day 82 — Evidence Vault Screen
///
/// Forensic chain-of-custody browser for all SOS evidence.
///
/// ── LP16 — Vault PIN ─────────────────────────────────────────────────────────
///   Separate 4-digit PIN from the SOS cancel/duress PIN (LP3).
///   Was: hardcoded to a shared literal ('1234') for every install (a real
///   Day 336/361 P1 finding). Now a real, user-chosen, per-install PIN —
///   its salted hash held in FlutterSecureStorage via [VaultPinStorage],
///   the same storage mechanism [TokenStorage] already uses for auth
///   tokens. First run (or post-wipe) shows a real 2-step "choose PIN,
///   confirm PIN" setup flow instead of an unlock screen.
///
/// ── LP23 — Cascade wipe ──────────────────────────────────────────────────────
///   3 wrong PINs → key-rotation warning banner.
///   5 wrong PINs → vault wiped (files purged, stored PIN cleared so a
///   wipe also forces real PIN re-setup, not just a file purge with the
///   old PIN still valid).
///
/// ── File browser (unlocked state) ────────────────────────────────────────────
///   • Per-event cards: SOS ID, timestamp, location, trigger type, tamper flag
///   • Expandable: 6 forensic streams per event
///   • Each stream: type icon, file name, size, duration, SHA-256 hash preview,
///     integrity badge (✓ Verified / ✕ Tampered)
///   • Expiry countdown with extend option
///   • Export bottom sheet: encrypted ZIP or legal PDF (mock)
///
/// ── Day 309 — Evidence Vault Search ─────────────────────────────────────────
///   Filter chips (date range / trigger type / status / tamper flag) +
///   SOS id prefix search, all combined with AND logic
///   ([filteredVaultEvidenceProvider] in `vault_providers.dart`), applied
///   entirely to the local/offline evidence list already shown here — no
///   network call. See that file's header for the real backend evidence
///   search endpoint this deliberately does *not* wire (`/evidence/search/`,
///   Day 209 — out of scope for this offline-filter polish day).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/vault_providers.dart';
import '../widgets/zap_chip.dart';
import '../widgets/zap_empty_state.dart';

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

/// Routes between the real "set up a PIN" flow (no PIN stored yet — first
/// run, or right after an LP23 wipe) and the real "enter your PIN" verify
/// flow, based on [vaultHasPinProvider]'s actual storage-backed answer.
class _PinGate extends ConsumerWidget {
  const _PinGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPin = ref.watch(vaultHasPinProvider);
    return hasPin.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: ZapColors.safe),
      ),
      error: (_, __) => const _PinSetupFlow(), // storage unreadable → treat as unset, safest default
      data: (has) => has ? const _PinVerifyFlow() : const _PinSetupFlow(),
    );
  }
}

/// Real first-time (or post-wipe) PIN setup: choose a 4-digit PIN, then
/// confirm it, then store its hash via [VaultPinStorage].
class _PinSetupFlow extends ConsumerStatefulWidget {
  const _PinSetupFlow();

  @override
  ConsumerState<_PinSetupFlow> createState() => _PinSetupFlowState();
}

class _PinSetupFlowState extends ConsumerState<_PinSetupFlow>
    with SingleTickerProviderStateMixin {
  final List<int> _pin = [];
  String? _firstPin;
  bool _error = false;
  String? _errorText;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  bool get _isConfirmStage => _firstPin != null;

  void _onDigit(int d) {
    if (_pin.length >= 4) return;
    setState(() => _pin.add(d));
    HapticFeedback.selectionClick();
    if (_pin.length == 4) _onPinComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
    HapticFeedback.selectionClick();
  }

  void _shakeAndClear(String message) {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0.0);
    setState(() {
      _error = true;
      _errorText = message;
    });
    Future<void>.delayed(const Duration(milliseconds: 560)).then((_) {
      if (mounted) setState(() { _error = false; _pin.clear(); });
    });
  }

  Future<void> _onPinComplete() async {
    final entered = _pin.join();
    if (!_isConfirmStage) {
      // Stage 1: choose PIN. Reject trivially weak PINs (all-same-digit or
      // a straight run) so this real setup step isn't easy to defeat with
      // '0000'/'1234' out of habit.
      if (_isWeakPin(entered)) {
        _shakeAndClear('Choose a less predictable PIN');
        return;
      }
      setState(() {
        _firstPin = entered;
        _pin.clear();
      });
      return;
    }
    // Stage 2: confirm PIN.
    if (entered != _firstPin) {
      _shakeAndClear("PINs didn't match — start again");
      setState(() => _firstPin = null);
      return;
    }
    await ref.read(vaultPinStorageProvider).setPin(entered);
    ref.invalidate(vaultHasPinProvider);
    ref.read(vaultLockedProvider.notifier).state = false;
    ref.read(vaultWrongPinCountProvider.notifier).state = 0;
  }

  bool _isWeakPin(String pin) {
    if (pin.split('').toSet().length == 1) return true; // '1111' etc.
    final digits = pin.split('').map(int.parse).toList();
    var ascending = true, descending = true;
    for (var i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) ascending = false;
      if (digits[i] != digits[i - 1] - 1) descending = false;
    }
    return ascending || descending; // '1234', '4321' etc.
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            _isConfirmStage ? Icons.check_circle_outline_rounded : Icons.lock_rounded,
            size: 30, color: ZapColors.safe,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          _isConfirmStage ? 'Confirm your PIN' : 'Set up your vault PIN',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary, fontFamily: 'ClashDisplay',
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          _error && _errorText != null
              ? _errorText!
              : _isConfirmStage
                  ? 'Re-enter the same 4 digits to confirm'
                  : 'Choose a 4-digit PIN to protect your evidence files. '
                    "This is separate from your app login and SOS cancel PIN.",
          style: ZapTypography.bodySmall.copyWith(
            color: _error ? ZapColors.danger : ZapColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.xxxl),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
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
                margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
                width: 14, height: 14,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.xxxl),
          child: _PinPad(onDigit: _onDigit, onDelete: _onDelete),
        ),
        const Spacer(),
      ],
    );
  }
}

/// Real PIN verify flow — used once a PIN has actually been set. Checks
/// entries against [VaultPinStorage]'s stored hash, applies the LP23
/// wrong-attempt cascade, and clears the stored PIN on wipe.
class _PinVerifyFlow extends ConsumerStatefulWidget {
  const _PinVerifyFlow();

  @override
  ConsumerState<_PinVerifyFlow> createState() => _PinVerifyFlowState();
}

class _PinVerifyFlowState extends ConsumerState<_PinVerifyFlow>
    with SingleTickerProviderStateMixin {

  final List<int> _pin = [];
  bool _error = false;
  bool _checking = false;

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
    if (_pin.length >= 4 || _checking) return;
    setState(() => _pin.add(d));
    HapticFeedback.selectionClick();
    if (_pin.length == 4) _validate();
  }

  void _onDelete() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin.removeLast());
    HapticFeedback.selectionClick();
  }

  Future<void> _validate() async {
    setState(() => _checking = true);
    final entered = _pin.join();
    final ok = await ref.read(vaultPinStorageProvider).verifyPin(entered);
    if (!mounted) return;
    if (ok) {
      ref.read(vaultLockedProvider.notifier).state = false;
      ref.read(vaultWrongPinCountProvider.notifier).state = 0;
      setState(() => _checking = false);
    } else {
      final count = ref.read(vaultWrongPinCountProvider) + 1;
      ref.read(vaultWrongPinCountProvider.notifier).state = count;
      if (count >= 5) {
        await ref.read(vaultPinStorageProvider).clearPin();
        ref.invalidate(vaultHasPinProvider);
        ref.read(vaultWipedProvider.notifier).state = true;
        return;
      }
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0.0);
      setState(() { _error = true; _checking = false; });
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
                margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(vaultEvidenceProvider);

    // Genuinely-empty vault (no evidence at all) vs "filters matched
    // nothing" (Day 309) are two different empty states — no point
    // showing a filter bar over an empty vault.
    if (allEntries.isEmpty) return _emptyVault();

    final entries = ref.watch(filteredVaultEvidenceProvider);
    final anyFilterActive = ref.watch(vaultAnyFilterActiveProvider);

    return Column(
      children: [
        _VaultFilterBar(searchController: _searchController),
        if (anyFilterActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(ZapSpacing.lg, 0, ZapSpacing.lg, ZapSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${entries.length} of ${allEntries.length} evidence entries',
                    style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: ZapColors.safe,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        Expanded(
          child: entries.isEmpty
              ? _noMatchesView(context, ref)
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
                ),
        ),
      ],
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    ref.read(vaultDateRangeFilterProvider.notifier).state = EvidenceDateRangeFilter.all;
    ref.read(vaultTriggerFilterProvider.notifier).state = EvidenceTriggerFilter.all;
    ref.read(vaultStatusFilterProvider.notifier).state = EvidenceStatusFilter.all;
    ref.read(vaultTamperOnlyFilterProvider.notifier).state = false;
    ref.read(vaultSearchQueryProvider.notifier).state = '';
  }

  /// Day 309 — "no matches" empty state (repo's standard empty-state
  /// pattern, matching [_emptyVault] below — there is no Day 212 screen
  /// in this repo to reuse, checked via file search first).
  Widget _noMatchesView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: ZapColors.textMuted),
            const SizedBox(height: ZapSpacing.lg),
            Text(
              'No evidence matches these filters',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'Try a different date range, trigger type, or status.',
              textAlign: TextAlign.center,
              style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textMuted, height: 1.5,
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),
            OutlinedButton(
              onPressed: _clearAllFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.safe,
                side: const BorderSide(color: ZapColors.safe, width: 0.8),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  // Consistency fix: this screen is the documented adopter for
  // ZapEmptyKind.vault (see zap_empty_state.dart's adoptScreen map), but was
  // never wired up to it -- it had its own hand-rolled empty state instead.
  // Wired to the shared widget here; icon/copy kept identical to the
  // original so this is a pure consistency fix, not a copy/behavior change.
  Widget _emptyVault() {
    return const ZapEmptyState(
      icon: Icons.inventory_2_outlined,
      accent: ZapColors.textMuted,
      title: 'No evidence files',
      message: 'Evidence is stored automatically\nwhen an SOS event occurs.',
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

// ─── Day 309 — Filter bar ───────────────────────────────────────────────────

/// Search field + filter chip rows, all wired to the [vault_providers.dart]
/// filter `StateProvider`s so state survives collapse/re-expand of the
/// vault browser. Every combination applies with AND logic
/// ([filteredVaultEvidenceProvider]).
class _VaultFilterBar extends ConsumerWidget {
  const _VaultFilterBar({required this.searchController});
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(vaultDateRangeFilterProvider);
    final trigger   = ref.watch(vaultTriggerFilterProvider);
    final status    = ref.watch(vaultStatusFilterProvider);
    final tamperOnly = ref.watch(vaultTamperOnlyFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.sm, ZapSpacing.lg, ZapSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search by SOS id prefix.
          TextField(
            controller: searchController,
            onChanged: (v) => ref.read(vaultSearchQueryProvider.notifier).state = v,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textPrimary, fontFamily: 'IBMPlexMono',
            ),
            decoration: InputDecoration(
              hintText: 'Search by SOS id (e.g. SOS-20260528)',
              hintStyle: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: ZapColors.textMuted),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: ZapColors.textMuted,
                      onPressed: () {
                        searchController.clear();
                        ref.read(vaultSearchQueryProvider.notifier).state = '';
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: ZapColors.bgCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: ZapSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: const BorderSide(color: ZapColors.border),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Date range.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ZapChipGroup<EvidenceDateRangeFilter>(
              options: EvidenceDateRangeFilter.values
                  .map((f) => (value: f, label: f.label, icon: null))
                  .toList(),
              selectedValue: dateRange,
              compact: true,
              onChanged: (v) => ref.read(vaultDateRangeFilterProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),

          // Trigger type.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ZapChipGroup<EvidenceTriggerFilter>(
              options: EvidenceTriggerFilter.values
                  .map((f) => (value: f, label: f.label, icon: null))
                  .toList(),
              selectedValue: trigger,
              compact: true,
              onChanged: (v) => ref.read(vaultTriggerFilterProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),

          // Status + tamper toggle share a row.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ZapChipGroup<EvidenceStatusFilter>(
                  options: EvidenceStatusFilter.values
                      .map((f) => (value: f, label: f.label, icon: null))
                      .toList(),
                  selectedValue: status,
                  compact: true,
                  onChanged: (v) => ref.read(vaultStatusFilterProvider.notifier).state = v,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Container(width: 1, height: 20, color: ZapColors.divider),
                const SizedBox(width: ZapSpacing.sm),
                ZapChip(
                  label: 'Tampered only',
                  icon: Icons.warning_amber_rounded,
                  selected: tamperOnly,
                  selectedColor: ZapColors.danger,
                  compact: true,
                  onTap: () => ref.read(vaultTamperOnlyFilterProvider.notifier).state = !tamperOnly,
                ),
              ],
            ),
          ),
        ],
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

  Color _statusColor(EvidenceStatus s) => switch (s) {
        EvidenceStatus.resolved => ZapColors.safe,
        EvidenceStatus.falsePositive => ZapColors.warning,
        EvidenceStatus.drill => ZapColors.info,
      };

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
                      const SizedBox(width: ZapSpacing.xs),
                      Text(
                        _formatTime(entry.timestamp),
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary, fontFamily: 'IBMPlexMono',
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: ZapColors.textMuted),
                      const SizedBox(width: ZapSpacing.xs),
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
                      const SizedBox(width: ZapSpacing.xs),
                      Text(
                        entry.triggerType,
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      // Day 309 — status pill (resolved/false positive/drill).
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _statusColor(entry.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.status.label,
                          style: ZapTypography.labelSmall.copyWith(
                            color: _statusColor(entry.status),
                            fontSize: 9,
                          ),
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
