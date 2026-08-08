/// Day 232 — Decoy Calculator Shell
///
/// Section B (Days 221-240): functional calculator decoy skin. Secret unlock:
/// press `=` three times, then enter `767` (SOS on phone keypad) to open
/// safety layer or navigate to Alert Pending. Hardware SOS remains active.
///
/// Tag: 🟢 FRONTEND-ONLY · LP24 stealth companion to Day 231 icon disguise.
///
/// Route: [AppRoutes.decoyCalculator] → `/decoy-calculator`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Calculator + secret state ─────────────────────────────────────────────────
class DecoyCalcState {
  const DecoyCalcState({
    this.display = '0',
    this.accumulator,
    this.pendingOp,
    this.freshEntry = true,
    this.eqStreak = 0,
    this.secretArmed = false,
    this.secretTail = '',
    this.unlocked = false,
    this.unlockCount = 0,
  });

  final String display;
  final double? accumulator;
  final String? pendingOp;
  final bool freshEntry;
  final int eqStreak;
  final bool secretArmed;
  final String secretTail;
  final bool unlocked;
  final int unlockCount;

  DecoyCalcState copyWith({
    String? display,
    double? accumulator,
    String? pendingOp,
    bool? freshEntry,
    bool clearPendingOp = false,
    bool clearAccumulator = false,
    int? eqStreak,
    bool? secretArmed,
    String? secretTail,
    bool? unlocked,
    int? unlockCount,
  }) {
    return DecoyCalcState(
      display: display ?? this.display,
      accumulator: clearAccumulator ? null : (accumulator ?? this.accumulator),
      pendingOp: clearPendingOp ? null : (pendingOp ?? this.pendingOp),
      freshEntry: freshEntry ?? this.freshEntry,
      eqStreak: eqStreak ?? this.eqStreak,
      secretArmed: secretArmed ?? this.secretArmed,
      secretTail: secretTail ?? this.secretTail,
      unlocked: unlocked ?? this.unlocked,
      unlockCount: unlockCount ?? this.unlockCount,
    );
  }
}

const _kSecretSuffix = '767'; // SOS on phone keypad (S=7, O=6, S=7)

double? _parseDisplay(String s) {
  if (s == 'Error') return null;
  return double.tryParse(s);
}

String _formatNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(6)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

double? _applyOp(double a, double b, String op) {
  return switch (op) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    '÷' => b == 0 ? null : a / b,
    _ => null,
  };
}

DecoyCalcState _inputDigit(DecoyCalcState s, String digit) {
  var next = s.copyWith(eqStreak: 0);
  var tail = s.secretArmed ? '${s.secretTail}$digit' : s.secretTail;

  var display = s.freshEntry ? digit : s.display + digit;
  if (display.startsWith('0') && digit != '.' && !display.contains('.')) {
    display = digit;
  }
  if (digit == '.' && s.freshEntry) display = '0.';
  if (!s.freshEntry && digit == '.' && s.display.contains('.')) {
    display = s.display;
  }

  next = next.copyWith(
    display: display,
    freshEntry: false,
    secretTail: tail,
  );

  if (next.secretArmed && tail.endsWith(_kSecretSuffix)) {
    return next.copyWith(
      unlocked: true,
      unlockCount: next.unlockCount + 1,
      secretArmed: false,
      secretTail: '',
      eqStreak: 0,
    );
  }
  return next;
}

DecoyCalcState _inputOp(DecoyCalcState s, String op) {
  final val = _parseDisplay(s.display);
  if (val == null) return s;

  double? acc = s.accumulator;
  if (acc != null && s.pendingOp != null && !s.freshEntry) {
    acc = _applyOp(acc, val, s.pendingOp!);
    if (acc == null) {
      return s.copyWith(display: 'Error', freshEntry: true, eqStreak: 0);
    }
  } else {
    acc = val;
  }

  return s.copyWith(
    accumulator: acc,
    pendingOp: op,
    freshEntry: true,
    display: _formatNum(acc),
    eqStreak: 0,
    secretTail: '',
  );
}

DecoyCalcState _inputEquals(DecoyCalcState s) {
  var eqStreak = s.eqStreak + 1;
  var secretArmed = s.secretArmed;
  var secretTail = s.secretTail;

  if (eqStreak >= 3) {
    secretArmed = true;
    secretTail = '';
    eqStreak = 0;
  }

  final val = _parseDisplay(s.display);
  if (val == null || s.pendingOp == null) {
    return s.copyWith(
      eqStreak: eqStreak,
      secretArmed: secretArmed,
      secretTail: secretTail,
    );
  }

  final result = _applyOp(s.accumulator ?? val, val, s.pendingOp!);
  if (result == null) {
    return s.copyWith(
      display: 'Error',
      freshEntry: true,
      clearPendingOp: true,
      clearAccumulator: true,
      eqStreak: eqStreak,
      secretArmed: secretArmed,
      secretTail: secretTail,
    );
  }

  return s.copyWith(
    display: _formatNum(result),
    freshEntry: true,
    clearPendingOp: true,
    clearAccumulator: true,
    eqStreak: eqStreak,
    secretArmed: secretArmed,
    secretTail: secretTail,
  );
}

DecoyCalcState _backspace(DecoyCalcState s) {
  if (s.freshEntry || s.display.length <= 1) {
    return s.copyWith(display: '0', freshEntry: true, eqStreak: 0);
  }
  final d = s.display.substring(0, s.display.length - 1);
  return s.copyWith(display: d.isEmpty ? '0' : d, eqStreak: 0);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d232TabProvider = StateProvider<int>((ref) => 0);
final _d232CalcProvider =
    StateProvider<DecoyCalcState>((ref) => const DecoyCalcState());

const _kTabs = ['Calculator', 'Secret Unlock', 'Safety'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day232DecoyCalculatorScreen extends ConsumerWidget {
  const Day232DecoyCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d232TabProvider);
    final calc = ref.watch(_d232CalcProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        foregroundColor: Colors.white,
        title: const Text('Calculator'),
        centerTitle: true,
        actions: [
          if (calc.secretArmed)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (calc.unlocked)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'UNLOCKED',
                    style: TextStyle(
                      color: Color(0xFF34C759),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _DecoyTabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d232TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _CalculatorTab(),
              1 => const _SecretUnlockTab(),
              _ => const _SafetyTab(),
            },
          ),
        ],
      ),
    );
  }
}

void _setCalc(WidgetRef ref, DecoyCalcState Function(DecoyCalcState) fn) {
  ref.read(_d232CalcProvider.notifier).update(fn);
}

// ── Tab 0: Calculator ─────────────────────────────────────────────────────────
class _CalculatorTab extends ConsumerWidget {
  const _CalculatorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(_d232CalcProvider);

    ref.listen<DecoyCalcState>(_d232CalcProvider, (prev, next) {
      if (next.unlocked && prev?.unlocked != true && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _showUnlockSheet(context, ref);
          _setCalc(ref, (s) => s.copyWith(unlocked: false));
        });
      }
    });

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            alignment: Alignment.bottomRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomRight,
              child: Text(
                calc.display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            child: Column(
              children: [
                _CalcRow(
                  keys: const [
                    _CalcKey('C', _KeyKind.fn),
                    _CalcKey('⌫', _KeyKind.fn),
                    _CalcKey('÷', _KeyKind.op),
                    _CalcKey('×', _KeyKind.op),
                  ],
                  ref: ref,
                ),
                _CalcRow(
                  keys: const [
                    _CalcKey('7', _KeyKind.digit),
                    _CalcKey('8', _KeyKind.digit),
                    _CalcKey('9', _KeyKind.digit),
                    _CalcKey('−', _KeyKind.op),
                  ],
                  ref: ref,
                ),
                _CalcRow(
                  keys: const [
                    _CalcKey('4', _KeyKind.digit),
                    _CalcKey('5', _KeyKind.digit),
                    _CalcKey('6', _KeyKind.digit),
                    _CalcKey('+', _KeyKind.op),
                  ],
                  ref: ref,
                ),
                _CalcRow(
                  keys: const [
                    _CalcKey('1', _KeyKind.digit),
                    _CalcKey('2', _KeyKind.digit),
                    _CalcKey('3', _KeyKind.digit),
                    _CalcKey('=', _KeyKind.eq),
                  ],
                  ref: ref,
                ),
                _CalcRow(
                  keys: const [
                    _CalcKey('0', _KeyKind.digit, wide: true),
                    _CalcKey('.', _KeyKind.digit),
                  ],
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _KeyKind { digit, op, eq, fn }

class _CalcKey {
  final String label;
  final _KeyKind kind;
  final bool wide;

  const _CalcKey(this.label, this.kind, {this.wide = false});
}

class _CalcRow extends StatelessWidget {
  final List<_CalcKey> keys;
  final WidgetRef ref;

  const _CalcRow({required this.keys, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: keys.map((k) {
          final flex = k.wide ? 2 : 1;
          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.xs),
              child: _CalcButton(
                label: k.label,
                kind: k.kind,
                onTap: () => _handleKey(ref, k),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _handleKey(WidgetRef ref, _CalcKey key) {
    switch (key.kind) {
      case _KeyKind.digit:
        _setCalc(ref, (s) => _inputDigit(s, key.label));
      case _KeyKind.op:
        final op = key.label == '−' ? '−' : key.label;
        _setCalc(ref, (s) => _inputOp(s, op));
      case _KeyKind.eq:
        _setCalc(ref, _inputEquals);
      case _KeyKind.fn:
        if (key.label == 'C') {
          _setCalc(ref, (_) => const DecoyCalcState());
        } else {
          _setCalc(ref, _backspace);
        }
    }
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final _KeyKind kind;
  final VoidCallback onTap;

  const _CalcButton({
    required this.label,
    required this.kind,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (kind) {
      case _KeyKind.fn:
        bg = const Color(0xFF505050);
        fg = Colors.white;
      case _KeyKind.op:
      case _KeyKind.eq:
        bg = const Color(0xFFFF9500);
        fg = Colors.white;
      case _KeyKind.digit:
        bg = const Color(0xFF3A3A3C);
        fg = Colors.white;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: kind == _KeyKind.eq ? 28 : 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

void _showUnlockSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: ZapColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: ZapColors.safe),
              SizedBox(width: ZapSpacing.sm),
              Text(
                'Safety layer unlocked',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Secret accepted: === then 767 (SOS keypad). Choose action:',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.alertPending);
            },
            icon: const Icon(Icons.timer_rounded, size: 18),
            label: const Text('Open Alert Pending'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: ZapColors.danger,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRoutes.sosActive);
            },
            icon: const Icon(Icons.sos_rounded, size: 18),
            label: const Text('Open SOS Active'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: ZapColors.warning,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Exit decoy → ZapSafe nav'),
          ),
        ],
      ),
    ),
  );
}

// ── Tab 1: Secret unlock ──────────────────────────────────────────────────────
class _SecretUnlockTab extends ConsumerWidget {
  const _SecretUnlockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(_d232CalcProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section B Day 12/20 · LP24 decoy shell',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Secret gesture',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        _StepCard(
          step: '1',
          title: 'Press = three times',
          body:
              'On the Calculator tab, tap the orange = key three times in a row '
              '(===). A green dot appears in the app bar when armed.',
          done: calc.secretArmed,
        ),
        _StepCard(
          step: '2',
          title: 'Enter 767 (SOS on keypad)',
          body: 'While armed, type 7 → 6 → 7 on the number pad. '
              'Maps to S-O-S on classic phone keys.',
          done: calc.unlockCount > 0,
        ),
        _StepCard(
          step: '3',
          title: 'Choose safety action',
          body:
              'Bottom sheet: Alert Pending, SOS Active, or exit to ZapSafe nav.',
          done: calc.unlockCount > 0,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                calc.secretArmed
                    ? 'Status: ARMED — enter 767 on keypad'
                    : calc.unlockCount > 0
                        ? 'Status: Unlocked ${calc.unlockCount} time(s) this session'
                        : 'Status: Decoy mode (standard calculator)',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _setCalc(
                        ref,
                        (s) => s.copyWith(
                          secretArmed: true,
                          secretTail: '',
                          eqStreak: 0,
                        ),
                      ),
                      child: const Text('Simulate arm'),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: calc.secretArmed
                          ? () {
                              _setCalc(
                                ref,
                                (s) => s.copyWith(
                                  secretTail: '${s.secretTail}$_kSecretSuffix',
                                  unlocked: true,
                                  unlockCount: s.unlockCount + 1,
                                  secretArmed: false,
                                ),
                              );
                            }
                          : null,
                      child: const Text('Simulate 767'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 233 Weather decoy'),
              onPressed: () => context.push(AppRoutes.decoyWeather),
            ),
            ActionChip(
              label: const Text('Day 231 disguise'),
              onPressed: () => context.push(AppRoutes.stealthIconDisguise),
            ),
            ActionChip(
              label: const Text('Day 230 hidden mode'),
              onPressed: () => context.push(AppRoutes.hiddenModeToggle),
            ),
            ActionChip(
              label: const Text('Day 234 Gesture config'),
              onPressed: () => context.push(AppRoutes.secretGestureConfig),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String body;
  final bool done;

  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: done ? ZapColors.safe.withOpacity(0.4) : ZapColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                done ? ZapColors.safe.withOpacity(0.2) : ZapColors.bgElevated,
            child: Text(
              done ? '✓' : step,
              style: TextStyle(
                color: done ? ZapColors.safe : ZapColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  body,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Safety ─────────────────────────────────────────────────────────────
class _SafetyTab extends StatelessWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sos_rounded, color: ZapColors.danger, size: 22),
                  SizedBox(width: ZapSpacing.sm),
                  Text(
                    'Hardware SOS always works',
                    style: TextStyle(
                      color: ZapColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Decoy calculator does NOT disable safety triggers. '
                'Power button ×5, volume SOS, and background DCS pipeline '
                'continue from the disguised launcher entry point.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Always-available triggers',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...const [
          (
            Icons.power_settings_new_rounded,
            'Power button ×5',
            'Day 76 · launches SOS Active even from decoy',
          ),
          (
            Icons.volume_up_rounded,
            'Volume hold pattern',
            'Configured in Day 234 secret gesture hub',
          ),
          (
            Icons.sensors_rounded,
            'DCS auto-SOS',
            'Background engine · LP25 passive flag',
          ),
          (
            Icons.fitness_center_rounded,
            'Drill mode',
            'Marked [DRILL] — does not dispatch live',
          ),
        ].map(
          (item) => ListTile(
            dense: true,
            leading: Icon(item.$1, color: ZapColors.info, size: 20),
            title: Text(
              item.$2,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              item.$3,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            'Hive: hidden_mode_prefs.decoy_shell = "calculator"\n'
            'Launch: activity-alias CalculatorActivity → DecoyCalculatorScreen\n'
            'Unlock: === + 767 → AlertPending | SosActive | home',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy safety contract',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'Decoy shell: hardware SOS always active. '
                      'Secret: === then 767.',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied safety note')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy safety contract'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 240 — Section B milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _DecoyTabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _DecoyTabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? const Color(0xFFFF9500)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white54,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
