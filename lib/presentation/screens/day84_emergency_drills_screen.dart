/// Day 84 — Emergency Drills Screen
///
/// Refinement of Day 60 drill mode with:
///   • Live animated SOS simulation — contacts respond one-by-one in real time
///   • Per-contact status cards (pending → responded / timeout)
///   • Elapsed timer + drill-phase state machine (setup → running → complete)
///   • Detailed scoring: A–F grade, 4-category breakdown, per-contact grades
///   • History list (last 5 drills from mock data)
///   • "DRILL MODE — NOT REAL" banners on all active states
///
/// Simulation runs entirely in-widget (Timer.periodic 100 ms).
/// Each contact has a mocked response window; no real notifications sent.
/// API integration: POST /api/v1/drill/start/ wired in Month 4.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

// ─── Simulation models ────────────────────────────────────────────────────────

enum DrillPhase { setup, running, complete }

enum ContactDrillStatus { pending, responded, timedOut }

class _SimContact {
  _SimContact({
    required this.name,
    required this.tier,
    required this.respondAtMs,  // null = will not respond
  });

  final String  name;
  final int     tier;
  final int?    respondAtMs;

  ContactDrillStatus status = ContactDrillStatus.pending;
  int?               actualResponseMs;

  Color get tierColor {
    switch (tier) {
      case 1:  return ZapColors.danger;
      case 2:  return ZapColors.warning;
      default: return ZapColors.info;
    }
  }

  String get responseLabel {
    if (status == ContactDrillStatus.pending) return '—';
    if (status == ContactDrillStatus.timedOut) return 'No response';
    final s = (actualResponseMs! / 1000).toStringAsFixed(1);
    return '${s}s';
  }
}

class _DrillScore {
  const _DrillScore({
    required this.total,
    required this.grade,
    required this.tier1Points,
    required this.tier2Points,
    required this.speedPoints,
    required this.coveragePoints,
    required this.recommendation,
    required this.previousTotal,
  });

  final int    total;
  final String grade;
  final int    tier1Points;    // max 40
  final int    tier2Points;    // max 30
  final int    speedPoints;    // max 20
  final int    coveragePoints; // max 10
  final String recommendation;
  final int?   previousTotal;

  int? get trend =>
      previousTotal == null ? null : total - previousTotal!;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day84EmergencyDrillsScreen extends ConsumerStatefulWidget {
  const Day84EmergencyDrillsScreen({super.key});

  @override
  ConsumerState<Day84EmergencyDrillsScreen> createState() =>
      _Day84EmergencyDrillsScreenState();
}

class _Day84EmergencyDrillsScreenState
    extends ConsumerState<Day84EmergencyDrillsScreen> {

  // ── Config ───────────────────────────────────────────────────────────────
  bool _includeTier1   = true;
  bool _includeTier2   = true;
  bool _includeTier3   = false;
  bool _simEscalation  = true;

  // ── Sim state ─────────────────────────────────────────────────────────────
  DrillPhase           _phase      = DrillPhase.setup;
  int                  _elapsedMs  = 0;
  List<_SimContact>    _contacts   = [];
  _DrillScore?         _score;
  Timer?               _ticker;

  // Drill duration = 10 000 ms simulated
  static const _kDrillDurationMs = 10000;

  // ── Mock history ──────────────────────────────────────────────────────────
  final _history = [
    _HistoryItem(date: DateTime.now().subtract(const Duration(days: 2)),
        grade: 'A', score: 91, trend: 3),
    _HistoryItem(date: DateTime.now().subtract(const Duration(days: 9)),
        grade: 'B', score: 78, trend: -5),
    _HistoryItem(date: DateTime.now().subtract(const Duration(days: 16)),
        grade: 'B', score: 83, trend: 11),
    _HistoryItem(date: DateTime.now().subtract(const Duration(days: 24)),
        grade: 'C', score: 72, trend: 2),
    _HistoryItem(date: DateTime.now().subtract(const Duration(days: 31)),
        grade: 'C', score: 70, trend: null),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── Simulation ────────────────────────────────────────────────────────────

  List<_SimContact> _buildContacts() {
    final rng = math.Random(42);
    final list = <_SimContact>[];

    if (_includeTier1) {
      list.add(_SimContact(
        name: 'Priya Sharma',
        tier: 1,
        respondAtMs: 800 + rng.nextInt(1500),
      ));
    }
    if (_includeTier2) {
      list.addAll([
        _SimContact(name: 'Rahul Gupta',  tier: 2, respondAtMs: 2000 + rng.nextInt(2000)),
        _SimContact(name: 'Anjali Mehta', tier: 2, respondAtMs: rng.nextBool() ? 3000 + rng.nextInt(3000) : null),
        _SimContact(name: 'Vikram Nair',  tier: 2, respondAtMs: 2500 + rng.nextInt(2500)),
      ]);
    }
    if (_includeTier3) {
      list.addAll([
        _SimContact(name: 'Sunita Patel',   tier: 3, respondAtMs: rng.nextBool() ? 4000 + rng.nextInt(4000) : null),
        _SimContact(name: 'Deepak Singh',   tier: 3, respondAtMs: rng.nextBool() ? 5000 + rng.nextInt(4000) : null),
        _SimContact(name: 'Meera Krishnan', tier: 3, respondAtMs: 6000 + rng.nextInt(3000)),
      ]);
    }

    return list;
  }

  void _startDrill() {
    final contacts = _buildContacts();
    setState(() {
      _phase      = DrillPhase.running;
      _elapsedMs  = 0;
      _contacts   = contacts;
      _score      = null;
    });

    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 100;

        for (final c in _contacts) {
          if (c.status == ContactDrillStatus.pending) {
            if (c.respondAtMs != null && _elapsedMs >= c.respondAtMs!) {
              c.status            = ContactDrillStatus.responded;
              c.actualResponseMs  = _elapsedMs;
            }
          }
        }

        if (_elapsedMs >= _kDrillDurationMs) {
          _completeDrill();
        }
      });
    });
  }

  void _completeDrill() {
    _ticker?.cancel();

    for (final c in _contacts) {
      if (c.status == ContactDrillStatus.pending) {
        c.status = ContactDrillStatus.timedOut;
      }
    }

    _score = _calcScore();
    _phase = DrillPhase.complete;
  }

  void _stopDrill() {
    _ticker?.cancel();
    setState(() {
      _phase     = DrillPhase.setup;
      _contacts  = [];
      _elapsedMs = 0;
    });
  }

  _DrillScore _calcScore() {
    final t1 = _contacts.where((c) => c.tier == 1).toList();
    final t2 = _contacts.where((c) => c.tier == 2).toList();
    final responded = _contacts.where((c) => c.status == ContactDrillStatus.responded).toList();

    // Tier 1 — 40 pts: full if responded, 0 if not (or absent)
    int tier1Pts = 0;
    if (t1.isEmpty) {
      tier1Pts = 20; // no tier 1 configured — half credit
    } else if (t1.any((c) => c.status == ContactDrillStatus.responded)) {
      final respMs = t1.first.actualResponseMs ?? _kDrillDurationMs;
      tier1Pts = respMs < 2000 ? 40 : respMs < 5000 ? 30 : 20;
    }

    // Tier 2 — 30 pts: proportional to coverage
    int tier2Pts = 0;
    if (t2.isNotEmpty) {
      final ackd = t2.where((c) => c.status == ContactDrillStatus.responded).length;
      tier2Pts = (ackd / t2.length * 30).round();
    } else {
      tier2Pts = 15;
    }

    // Speed — 20 pts: based on average response time of responders
    int speedPts = 0;
    if (responded.isNotEmpty) {
      final avgMs = responded
          .map((c) => c.actualResponseMs ?? _kDrillDurationMs)
          .reduce((a, b) => a + b) ~/
          responded.length;
      speedPts = avgMs < 2000 ? 20 : avgMs < 4000 ? 15 : avgMs < 7000 ? 10 : 5;
    }

    // Coverage — 10 pts: % of all contacts who responded
    int covPts = 0;
    if (_contacts.isNotEmpty) {
      final pct = responded.length / _contacts.length;
      covPts = (pct * 10).round();
    }

    final total = (tier1Pts + tier2Pts + speedPts + covPts).clamp(0, 100);

    String grade;
    if (total >= 90)      { grade = 'A'; }
    else if (total >= 80) { grade = 'B'; }
    else if (total >= 70) { grade = 'C'; }
    else if (total >= 60) { grade = 'D'; }
    else                  { grade = 'F'; }

    String rec;
    if (t1.isEmpty) {
      rec = 'Add a Tier 1 emergency contact to maximize your drill score.';
    } else if (tier1Pts < 30) {
      rec = 'Your Tier 1 contact is slow to respond. Share the app guide with them.';
    } else if (tier2Pts < 20) {
      rec = 'Tier 2 coverage is low. Check that all contacts have notifications enabled.';
    } else if (speedPts < 10) {
      rec = 'Average response time is high. Run drills more frequently to build habit.';
    } else {
      rec = 'Excellent drill! Keep running drills monthly to maintain readiness.';
    }

    return _DrillScore(
      total:          total,
      grade:          grade,
      tier1Points:    tier1Pts,
      tier2Points:    tier2Pts,
      speedPoints:    speedPts,
      coveragePoints: covPts,
      recommendation: rec,
      previousTotal:  _history.isNotEmpty ? _history.first.score : null,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:  ZapColors.bgPrimary,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: _phase == DrillPhase.running
            ? const SizedBox.shrink()
            : const BackButton(color: ZapColors.textPrimary),
        title: Text(
          'Emergency Drills',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        actions: [
          if (_phase == DrillPhase.running)
            TextButton.icon(
              onPressed: _stopDrill,
              icon:      const Icon(Icons.stop_rounded, size: 16),
              label:     const Text('Stop'),
              style: TextButton.styleFrom(foregroundColor: ZapColors.danger),
            ),
        ],
      ),
      body: switch (_phase) {
        DrillPhase.setup    => _SetupBody(
            includeTier1:    _includeTier1,
            includeTier2:    _includeTier2,
            includeTier3:    _includeTier3,
            simEscalation:   _simEscalation,
            history:         _history,
            onTier1:    (v) => setState(() => _includeTier1   = v),
            onTier2:    (v) => setState(() => _includeTier2   = v),
            onTier3:    (v) => setState(() => _includeTier3   = v),
            onEscalation:(v)=> setState(() => _simEscalation  = v),
            onStart:         _startDrill,
          ),
        DrillPhase.running  => _RunningBody(
            elapsedMs: _elapsedMs,
            contacts:  _contacts,
          ),
        DrillPhase.complete => _ResultsBody(
            score:     _score!,
            contacts:  _contacts,
            onRunAgain: () => setState(() {
              _phase     = DrillPhase.setup;
              _contacts  = [];
              _elapsedMs = 0;
            }),
          ),
      },
    );
  }
}

// ─── Setup body ───────────────────────────────────────────────────────────────

class _SetupBody extends StatelessWidget {
  const _SetupBody({
    required this.includeTier1,
    required this.includeTier2,
    required this.includeTier3,
    required this.simEscalation,
    required this.history,
    required this.onTier1,
    required this.onTier2,
    required this.onTier3,
    required this.onEscalation,
    required this.onStart,
  });

  final bool                   includeTier1;
  final bool                   includeTier2;
  final bool                   includeTier3;
  final bool                   simEscalation;
  final List<_HistoryItem>     history;
  final void Function(bool)    onTier1;
  final void Function(bool)    onTier2;
  final void Function(bool)    onTier3;
  final void Function(bool)    onEscalation;
  final VoidCallback           onStart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl * 2,
      ),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color:        ZapColors.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: ZapColors.info, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'No real alerts are sent during a drill. '
                  'Contacts receive a clearly-marked practice notification.',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.info, height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Config
        const _SectionLabel('DRILL CONFIGURATION'),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color:        ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              _ConfigRow(
                label:   'Include Tier 1',
                sub:     'Primary emergency contact',
                value:   includeTier1,
                accent:  ZapColors.danger,
                onChanged: onTier1,
              ),
              const Divider(color: ZapColors.divider, height: 1),
              _ConfigRow(
                label:   'Include Tier 2',
                sub:     'Escalation contacts',
                value:   includeTier2,
                accent:  ZapColors.warning,
                onChanged: onTier2,
              ),
              const Divider(color: ZapColors.divider, height: 1),
              _ConfigRow(
                label:   'Include Tier 3',
                sub:     'Broadcast ring',
                value:   includeTier3,
                accent:  ZapColors.info,
                onChanged: onTier3,
              ),
              const Divider(color: ZapColors.divider, height: 1),
              _ConfigRow(
                label:   'Simulate escalation',
                sub:     'Auto-escalate if Tier 1 silent',
                value:   simEscalation,
                accent:  ZapColors.safe,
                onChanged: onEscalation,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Start button
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon:  const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('Run Drill'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ZapColors.safe,
              foregroundColor: Colors.white,
              textStyle:       ZapTypography.headlineSmall,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.xxxl),

        // History
        const _SectionLabel('RECENT DRILLS'),
        const SizedBox(height: ZapSpacing.sm),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.xl),
            child: Text(
              'No drills run yet.',
              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textMuted),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...history.map((h) => _HistoryTile(item: h)),
      ],
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String           label;
  final String           sub;
  final bool             value;
  final Color            accent;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textPrimary,
                )),
                Text(sub, style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                )),
              ],
            ),
          ),
          Switch(
            value:              value,
            onChanged:          onChanged,
            activeColor:        accent,
            activeTrackColor:   accent.withOpacity(0.3),
            inactiveTrackColor: ZapColors.bgSurface,
            inactiveThumbColor: ZapColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─── Running body ─────────────────────────────────────────────────────────────

class _RunningBody extends StatelessWidget {
  const _RunningBody({required this.elapsedMs, required this.contacts});

  final int               elapsedMs;
  final List<_SimContact> contacts;

  String get _timerLabel {
    final s  = elapsedMs ~/ 1000;
    final ms = (elapsedMs % 1000) ~/ 100;
    return '${s.toString().padLeft(2, '0')}.${ms}s';
  }

  double get _progress => (elapsedMs / _Day84EmergencyDrillsScreenState._kDrillDurationMs).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final responded = contacts.where((c) => c.status == ContactDrillStatus.responded).length;

    return Column(
      children: [
        // DRILL banner
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          color:   ZapColors.warning.withOpacity(0.15),
          child: Text(
            'DRILL MODE  ·  NO REAL ALERTS SENT',
            textAlign: TextAlign.center,
            style: ZapTypography.labelSmall.copyWith(
              color:         ZapColors.warning,
              letterSpacing: 1.2,
              fontWeight:    FontWeight.w700,
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: ZapSpacing.xl),

                // Timer
                Text(
                  _timerLabel,
                  style: const TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize:   72,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                    height:     1.0,
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           _progress,
                    minHeight:       6,
                    backgroundColor: ZapColors.bgSurface,
                    valueColor:      const AlwaysStoppedAnimation<Color>(ZapColors.warning),
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  '$responded / ${contacts.length} responded',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary),
                ),
                const SizedBox(height: ZapSpacing.xxxl),

                // Contact cards
                const _SectionLabel('CONTACT SIMULATION'),
                const SizedBox(height: ZapSpacing.sm),
                ...contacts.map((c) => _RunningContactCard(contact: c)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RunningContactCard extends StatelessWidget {
  const _RunningContactCard({required this.contact});
  final _SimContact contact;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (contact.status) {
      case ContactDrillStatus.pending:
        statusColor = ZapColors.textMuted;
        statusIcon  = Icons.hourglass_empty_rounded;
        statusLabel = 'Waiting…';
      case ContactDrillStatus.responded:
        statusColor = ZapColors.safe;
        statusIcon  = Icons.check_circle_rounded;
        statusLabel = contact.responseLabel;
      case ContactDrillStatus.timedOut:
        statusColor = ZapColors.danger;
        statusIcon  = Icons.cancel_rounded;
        statusLabel = 'No response';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: contact.status == ContactDrillStatus.pending
              ? ZapColors.border
              : statusColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          // Tier badge
          Container(
            width:  36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: contact.tierColor.withOpacity(0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              'T${contact.tier}',
              style: ZapTypography.labelSmall.copyWith(
                color:      contact.tierColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Name
          Expanded(
            child: Text(
              contact.name,
              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
            ),
          ),

          // Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  statusIcon,
                  key:   ValueKey(contact.status),
                  size:  18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: ZapTypography.labelMedium.copyWith(
                  color:      statusColor,
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Results body ─────────────────────────────────────────────────────────────

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.score,
    required this.contacts,
    required this.onRunAgain,
  });

  final _DrillScore        score;
  final List<_SimContact>  contacts;
  final VoidCallback       onRunAgain;

  Color get _gradeColor {
    switch (score.grade) {
      case 'A':  return ZapColors.safe;
      case 'B':  return ZapColors.info;
      case 'C':  return ZapColors.warning;
      default:   return ZapColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl * 2,
      ),
      children: [
        // ── Grade card ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(ZapSpacing.xl),
          decoration: BoxDecoration(
            color:        ZapColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border:       Border.all(color: _gradeColor.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              // Grade badge
              Container(
                width:  80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gradeColor.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  score.grade,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize:   44,
                    fontWeight: FontWeight.w700,
                    color:      _gradeColor,
                    height:     1.0,
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.md),

              Text(
                '${score.total} / 100',
                style: ZapTypography.headlineMedium.copyWith(
                  color:      ZapColors.textPrimary,
                  fontFamily: 'ClashDisplay',
                ),
              ),

              if (score.trend != null) ...[
                const SizedBox(height: ZapSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      score.trend! >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size:  14,
                      color: score.trend! >= 0 ? ZapColors.safe : ZapColors.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${score.trend! >= 0 ? '+' : ''}${score.trend} vs last drill',
                      style: ZapTypography.bodySmall.copyWith(
                        color: score.trend! >= 0 ? ZapColors.safe : ZapColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Score breakdown ────────────────────────────────────────────────
        const _SectionLabel('SCORE BREAKDOWN'),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color:        ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              _ScoreRow(label: 'Tier 1 response',  pts: score.tier1Points,    maxPts: 40, color: ZapColors.danger),
              const SizedBox(height: ZapSpacing.md),
              _ScoreRow(label: 'Tier 2 coverage',  pts: score.tier2Points,    maxPts: 30, color: ZapColors.warning),
              const SizedBox(height: ZapSpacing.md),
              _ScoreRow(label: 'Response speed',   pts: score.speedPoints,    maxPts: 20, color: ZapColors.info),
              const SizedBox(height: ZapSpacing.md),
              _ScoreRow(label: 'Overall coverage', pts: score.coveragePoints, maxPts: 10, color: ZapColors.safe),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Per-contact results ────────────────────────────────────────────
        const _SectionLabel('CONTACT RESULTS'),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color:        ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: contacts.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final isLast = i == contacts.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.lg,
                      vertical:   ZapSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.tierColor.withOpacity(0.12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'T${c.tier}',
                            style: ZapTypography.labelSmall.copyWith(
                              color:      c.tierColor,
                              fontWeight: FontWeight.w700,
                              fontSize:   9,
                            ),
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Text(
                            c.name,
                            style: ZapTypography.bodyMedium.copyWith(
                              color: ZapColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          c.responseLabel,
                          style: ZapTypography.labelMedium.copyWith(
                            color: c.status == ContactDrillStatus.responded
                                ? ZapColors.safe
                                : ZapColors.danger,
                            fontFamily: 'IBMPlexMono',
                            fontSize:   12,
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Icon(
                          c.status == ContactDrillStatus.responded
                              ? Icons.check_circle_outline_rounded
                              : Icons.cancel_outlined,
                          size:  16,
                          color: c.status == ContactDrillStatus.responded
                              ? ZapColors.safe
                              : ZapColors.danger,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      color: ZapColors.divider, height: 1,
                      indent: ZapSpacing.lg, endIndent: ZapSpacing.lg,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Recommendation ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color:        _gradeColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: _gradeColor.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _gradeColor, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  score.recommendation,
                  style: ZapTypography.bodyMedium.copyWith(
                    color: _gradeColor, height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Actions ────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onRunAgain,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZapColors.textSecondary,
                  side: const BorderSide(color: ZapColors.border),
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Run again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.pts,
    required this.maxPts,
    required this.color,
  });

  final String label;
  final int    pts;
  final int    maxPts;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
            )),
            Text(
              '$pts / $maxPts',
              style: ZapTypography.labelMedium.copyWith(
                color:      color,
                fontFamily: 'IBMPlexMono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value:           (pts / maxPts).clamp(0.0, 1.0),
            minHeight:       8,
            backgroundColor: ZapColors.bgSurface,
            valueColor:      AlwaysStoppedAnimation<Color>(color.withOpacity(0.75)),
          ),
        ),
      ],
    );
  }
}

// ─── History item ─────────────────────────────────────────────────────────────

class _HistoryItem {
  const _HistoryItem({
    required this.date,
    required this.grade,
    required this.score,
    required this.trend,
  });

  final DateTime date;
  final String   grade;
  final int      score;
  final int?     trend;
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final _HistoryItem item;

  Color get _gradeColor {
    switch (item.grade) {
      case 'A': return ZapColors.safe;
      case 'B': return ZapColors.info;
      case 'C': return ZapColors.warning;
      default:  return ZapColors.danger;
    }
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${diff}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: ZapColors.border),
      ),
      child: Row(
        children: [
          // Grade
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gradeColor.withOpacity(0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              item.grade,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize:   20,
                fontWeight: FontWeight.w700,
                color:      _gradeColor,
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),

          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(item.date),
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                  ),
                ),
                Text(
                  'Score: ${item.score}',
                  style: ZapTypography.bodySmall.copyWith(
                    color:      ZapColors.textSecondary,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ],
            ),
          ),

          // Trend
          if (item.trend != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.trend! >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size:  13,
                  color: item.trend! >= 0 ? ZapColors.safe : ZapColors.danger,
                ),
                const SizedBox(width: 2),
                Text(
                  '${item.trend! >= 0 ? '+' : ''}${item.trend}',
                  style: ZapTypography.labelSmall.copyWith(
                    color: item.trend! >= 0 ? ZapColors.safe : ZapColors.danger,
                    fontFamily: 'IBMPlexMono',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ZapTypography.labelSmall.copyWith(
        color:         ZapColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}
