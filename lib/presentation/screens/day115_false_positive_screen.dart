/// Day 115 — False Positive Report Flow
///
/// Post-SOS dialog: "Was this a false alarm?" Appears 2 seconds after SOS
/// confirmation. Two buttons (Yes = false alarm / No = real emergency).
/// Mock POST to /api/v1/feedback/false-positive. Snackbar confirmation.
/// Reports feed back into ML training pipeline to reduce false SOS triggers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _DialogState { waiting, visible, submitting, done }
enum _FalsePositiveResult { falseAlarm, realEmergency }

// ── Providers ──────────────────────────────────────────────────────────────────
final _dialogStateProvider = StateProvider<_DialogState>(
  (ref) => _DialogState.waiting,
);
final _resultProvider =
    StateProvider<_FalsePositiveResult?>((ref) => null);
final _countdownProvider = StateProvider<int>((ref) => 2);

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day115FalsePositiveScreen extends ConsumerStatefulWidget {
  const Day115FalsePositiveScreen({super.key});

  @override
  ConsumerState<Day115FalsePositiveScreen> createState() =>
      _Day115FalsePositiveScreenState();
}

class _Day115FalsePositiveScreenState
    extends ConsumerState<Day115FalsePositiveScreen> {

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  Future<void> _startCountdown() async {
    for (int i = 2; i >= 1; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      ref.read(_countdownProvider.notifier).state = i - 1;
    }
    if (!mounted) return;
    ref.read(_dialogStateProvider.notifier).state = _DialogState.visible;
    _showDialog();
  }

  void _showDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FalseAlarmDialog(
        onFalseAlarm: () => _handleSelection(_FalsePositiveResult.falseAlarm),
        onRealEmergency: () =>
            _handleSelection(_FalsePositiveResult.realEmergency),
      ),
    );
  }

  Future<void> _handleSelection(_FalsePositiveResult result) async {
    Navigator.of(context).pop(); // close dialog
    ref.read(_resultProvider.notifier).state = result;
    ref.read(_dialogStateProvider.notifier).state = _DialogState.submitting;

    // Mock POST /api/v1/feedback/false-positive
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    ref.read(_dialogStateProvider.notifier).state = _DialogState.done;

    final msg = result == _FalsePositiveResult.falseAlarm
        ? 'Logged as false alarm — thanks! This trains our model.'
        : 'Logged as real emergency — stay safe.';
    final color = result == _FalsePositiveResult.falseAlarm
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result == _FalsePositiveResult.falseAlarm
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
        ),
      );
    }
  }

  void _reset() {
    ref.read(_dialogStateProvider.notifier).state = _DialogState.waiting;
    ref.read(_resultProvider.notifier).state = null;
    ref.read(_countdownProvider.notifier).state = 2;
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final dialogState = ref.watch(_dialogStateProvider);
    final result      = ref.watch(_resultProvider);
    final countdown   = ref.watch(_countdownProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 115 · False Positive Flow'),
        elevation: 0,
        actions: [
          if (dialogState == _DialogState.done)
            TextButton(
              onPressed: _reset,
              child: const Text(
                'Replay',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
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

            // ── Live state card ───────────────────────────────────────────
            _StateCard(
              dialogState: dialogState,
              result: result,
              countdown: countdown,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── Mock SOS context ──────────────────────────────────────────
            const _SectionLabel('SOS EVENT CONTEXT'),
            const SizedBox(height: ZapSpacing.md),
            const _SosContextCard(),
            const SizedBox(height: ZapSpacing.xl),

            // ── Flow explanation ──────────────────────────────────────────
            const _SectionLabel('HOW IT WORKS'),
            const SizedBox(height: ZapSpacing.md),
            const _FlowSteps(),
            const SizedBox(height: ZapSpacing.xl),

            // ── Backend payload ───────────────────────────────────────────
            const _SectionLabel('BACKEND PAYLOAD'),
            const SizedBox(height: ZapSpacing.md),
            const _PayloadCard(),
            const SizedBox(height: ZapSpacing.xl),

            // ── ML impact ────────────────────────────────────────────────
            const _SectionLabel('ML TRAINING IMPACT'),
            const SizedBox(height: ZapSpacing.md),
            const _MlImpactCard(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── False alarm dialog ─────────────────────────────────────────────────────────
class _FalseAlarmDialog extends StatelessWidget {
  final VoidCallback onFalseAlarm;
  final VoidCallback onRealEmergency;

  const _FalseAlarmDialog({
    required this.onFalseAlarm,
    required this.onRealEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        side: BorderSide(
          color: const Color(0xFFF59E0B).withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 32,
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // Title
            const Text(
              'Was this a false alarm?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Message
            const Text(
              'Help us improve detection by reporting false alarms. '
              'Your response trains our AI model.',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Buttons
            GestureDetector(
              onTap: onFalseAlarm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: ZapSpacing.sm),
                    Text(
                      'Yes, this was false',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            GestureDetector(
              onTap: onRealEmergency,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_rounded,
                        color: Color(0xFF10B981), size: 20),
                    SizedBox(width: ZapSpacing.sm),
                    Text(
                      'No, it was real emergency',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          colors: [Color(0xFF422006), Color(0xFF1C0F02), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_rounded,
                    color: Color(0xFFF59E0B), size: 13),
                SizedBox(width: 5),
                Text(
                  '⚡  BETA  ·  DAY 115',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'False Positive\nReport Flow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '2 seconds after SOS confirmation, this dialog appears. '
            'User reports whether it was a false alarm. Data goes to '
            'POST /api/v1/feedback/false-positive to train the ML model.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('2s',   'Delay after SOS', Color(0xFFF59E0B)),
              _HeroStat('ML',   'Training data',   Color(0xFF3B82F6)),
              _HeroStat('100%', 'Must acknowledge', Color(0xFFEF4444)),
              _HeroStat('↓FP',  'Reduces FP rate', Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label,
              style:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Live state card ────────────────────────────────────────────────────────────
class _StateCard extends StatelessWidget {
  final _DialogState dialogState;
  final _FalsePositiveResult? result;
  final int countdown;

  const _StateCard({
    required this.dialogState,
    required this.result,
    required this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: _bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: _bgColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(_icon, color: _bgColor, size: 40),
          const SizedBox(height: ZapSpacing.md),
          Text(
            _title,
            style: TextStyle(
              color: _bgColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            _subtitle,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (dialogState == _DialogState.waiting && countdown > 0) ...[
            const SizedBox(height: ZapSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                ),
              ),
              child: Text(
                'Dialog appears in ${countdown}s…',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (dialogState == _DialogState.done && result != null) ...[
            const SizedBox(height: ZapSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Text(
                result == _FalsePositiveResult.falseAlarm
                    ? '{ is_false_alarm: true, sos_id: "sos_mock_001" }'
                    : '{ is_false_alarm: false, sos_id: "sos_mock_001" }',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color get _bgColor {
    switch (dialogState) {
      case _DialogState.waiting:
        return const Color(0xFFF59E0B);
      case _DialogState.visible:
        return const Color(0xFF3B82F6);
      case _DialogState.submitting:
        return const Color(0xFF8B5CF6);
      case _DialogState.done:
        return result == _FalsePositiveResult.falseAlarm
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981);
    }
  }

  IconData get _icon {
    switch (dialogState) {
      case _DialogState.waiting:
        return Icons.hourglass_top_rounded;
      case _DialogState.visible:
        return Icons.help_outline_rounded;
      case _DialogState.submitting:
        return Icons.cloud_upload_rounded;
      case _DialogState.done:
        return result == _FalsePositiveResult.falseAlarm
            ? Icons.warning_amber_rounded
            : Icons.verified_rounded;
    }
  }

  String get _title {
    switch (dialogState) {
      case _DialogState.waiting:
        return 'SOS Resolved — Waiting 2s';
      case _DialogState.visible:
        return 'Dialog Shown';
      case _DialogState.submitting:
        return 'Submitting to Backend…';
      case _DialogState.done:
        return result == _FalsePositiveResult.falseAlarm
            ? 'False Alarm Logged'
            : 'Real Emergency Logged';
    }
  }

  String get _subtitle {
    switch (dialogState) {
      case _DialogState.waiting:
        return 'SOS confirmed. Dialog auto-appears after 2 second delay.';
      case _DialogState.visible:
        return '"Was this a false alarm?" — user must acknowledge.';
      case _DialogState.submitting:
        return 'POST /api/v1/feedback/false-positive in progress…';
      case _DialogState.done:
        return result == _FalsePositiveResult.falseAlarm
            ? 'Payload sent to backend for ML training. FP rate will decrease.'
            : 'Real emergency confirmed. No model adjustment needed.';
    }
  }
}

// ── SOS context card ───────────────────────────────────────────────────────────
class _SosContextCard extends StatelessWidget {
  const _SosContextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          _ContextRow(
            icon: Icons.bolt_rounded,
            color: const Color(0xFFEF4444),
            label: 'Trigger',
            value: 'Scream detected (94% confidence)',
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ContextRow(
            icon: Icons.access_time_rounded,
            color: const Color(0xFF3B82F6),
            label: 'Time',
            value: '12:45 PM · 2s ago',
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ContextRow(
            icon: Icons.people_rounded,
            color: const Color(0xFF10B981),
            label: 'Notified',
            value: '3 contacts alerted',
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ContextRow(
            icon: Icons.tag_rounded,
            color: const Color(0xFF8B5CF6),
            label: 'SOS ID',
            value: 'sos_mock_001',
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;

  const _ContextRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.md),
          Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flow steps ─────────────────────────────────────────────────────────────────
const _kSteps = [
  (Icons.bolt_rounded,        Color(0xFFEF4444), 'SOS fires',
      'DCS triggers SOS. Contacts notified. Evidence capture starts.'),
  (Icons.hourglass_top_rounded, Color(0xFFF59E0B), 'Wait 2 seconds',
      'Brief delay gives user time to process what just happened before the dialog.'),
  (Icons.help_outline_rounded, Color(0xFF3B82F6), 'Dialog appears',
      '"Was this a false alarm?" — barrierDismissible: false. User must answer.'),
  (Icons.cloud_upload_rounded, Color(0xFF8B5CF6), 'POST to backend',
      '/api/v1/feedback/false-positive with sos_id, is_false_alarm, timestamp.'),
  (Icons.model_training_rounded, Color(0xFF10B981), 'ML training',
      'False alarm reports label training data → model retrained → lower FP rate.'),
];

class _FlowSteps extends StatelessWidget {
  const _FlowSteps();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_kSteps.length, (i) {
        final (icon, color, title, desc) = _kSteps[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (i < _kSteps.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: const Color(0xFF2A2A2A),
                  ),
              ],
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: ZapSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Payload card ───────────────────────────────────────────────────────────────
class _PayloadCard extends StatelessWidget {
  const _PayloadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POST  /api/v1/feedback/false-positive',
            style: TextStyle(
              color: Color(0xFF79C0FF),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ZapSpacing.md),
          Text(
            '{\n'
            '  "sos_id":        "sos_mock_001",\n'
            '  "is_false_alarm": true | false,\n'
            '  "timestamp":     "2026-05-29T14:23:00Z"\n'
            '}',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── ML impact card ─────────────────────────────────────────────────────────────
class _MlImpactCard extends StatelessWidget {
  const _MlImpactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: const Column(
        children: [
          _ImpactRow(
            icon: Icons.trending_down_rounded,
            color: Color(0xFF10B981),
            title: 'False positive rate',
            value: '8% → <5%',
            note: 'Target after 1000 beta reports',
          ),
          Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ImpactRow(
            icon: Icons.model_training_rounded,
            color: Color(0xFF3B82F6),
            title: 'Models improved',
            value: 'M1 Scream, M2 Motion',
            note: 'Reports labelled as training data',
          ),
          Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ImpactRow(
            icon: Icons.people_rounded,
            color: Color(0xFF8B5CF6),
            title: 'Reports needed',
            value: '500+ false alarms',
            note: 'For statistically significant retraining',
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value, note;

  const _ImpactRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(note,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
