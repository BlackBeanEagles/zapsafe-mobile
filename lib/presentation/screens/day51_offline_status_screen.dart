import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/connectivity_service.dart';
import '../../domain/providers/connectivity_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

/// Day 51 — Offline Status Screen.
///
/// Route: /offline-status
///
/// Shows the user exactly what ZapSafe can do without internet, what needs
/// a connection, and the current queue of events waiting to be dispatched
/// when the network returns.
///
/// Architecture note: ZapSafe is offline-first. All AI inference, SOS
/// recording, and evidence capture run entirely on-device. The network is
/// only required to *dispatch* the SOS to the backend and trusted contacts.
/// Pending dispatches are queued in local storage and retried automatically
/// once connectivity returns.
class Day51OfflineStatusScreen extends ConsumerWidget {
  const Day51OfflineStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectAsync = ref.watch(connectivityTypeProvider);
    final type = connectAsync.valueOrNull ?? ConnectivityType.none;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Offline Status',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 51',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Live connection status ─────────────────────────────────────
            _ConnectionStatusCard(type: type),
            const SizedBox(height: ZapSpacing.xl),

            // ── Offline capability list ────────────────────────────────────
            _SectionLabel('WORKS OFFLINE'),
            const SizedBox(height: ZapSpacing.sm),
            const _CapabilityTable(online: false),
            const SizedBox(height: ZapSpacing.xl),

            // ── Online-only features ───────────────────────────────────────
            _SectionLabel('NEEDS INTERNET'),
            const SizedBox(height: ZapSpacing.sm),
            const _CapabilityTable(online: true),
            const SizedBox(height: ZapSpacing.xl),

            // ── Pending queue ──────────────────────────────────────────────
            _SectionLabel('PENDING QUEUE'),
            const SizedBox(height: ZapSpacing.sm),
            const _PendingQueueCard(),
            const SizedBox(height: ZapSpacing.xl),

            // ── Local storage indicator ────────────────────────────────────
            _SectionLabel('LOCAL STORAGE'),
            const SizedBox(height: ZapSpacing.sm),
            const _LocalStorageCard(),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Connection status card ───────────────────────────────────────────────────

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.type});
  final ConnectivityType type;

  Color get _color {
    switch (type) {
      case ConnectivityType.wifi:   return ZapColors.safe;
      case ConnectivityType.mobile: return ZapColors.info;
      case ConnectivityType.none:   return ZapColors.danger;
    }
  }

  IconData get _icon {
    switch (type) {
      case ConnectivityType.wifi:   return Icons.wifi_rounded;
      case ConnectivityType.mobile: return Icons.signal_cellular_alt_rounded;
      case ConnectivityType.none:   return Icons.wifi_off_rounded;
    }
  }

  String get _label {
    switch (type) {
      case ConnectivityType.wifi:   return 'WiFi';
      case ConnectivityType.mobile: return 'Mobile Data';
      case ConnectivityType.none:   return 'Offline';
    }
  }

  String get _sublabel {
    switch (type) {
      case ConnectivityType.wifi:
        return 'Full connectivity — SOS dispatch active';
      case ConnectivityType.mobile:
        return 'Cellular connection — SOS dispatch active';
      case ConnectivityType.none:
        return 'No network — SOS queued locally for retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(_icon, color: _color, size: 26),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: ZapTypography.labelLarge.copyWith(
                    color: _color,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sublabel,
                  style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary),
                ),
              ],
            ),
          ),
          // Pulse dot
          _PulseDot(color: _color, active: type != ConnectivityType.none),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      );
}

// ─── Capability table ─────────────────────────────────────────────────────────

class _CapabilityTable extends StatelessWidget {
  const _CapabilityTable({required this.online});

  /// If true, shows features that NEED internet.
  /// If false, shows features that work OFFLINE.
  final bool online;

  static const List<(IconData, String, String)> _offlineFeatures = [
    (Icons.mic_rounded,
        'Scream / audio detection',
        'Runs fully on-device via TFLite or heuristic'),
    (Icons.vibration_rounded,
        'Motion & fall detection',
        'IMU sensors + HeuristicMotionDetector'),
    (Icons.pan_tool_rounded,
        'Manual SOS button',
        'Queues event locally for dispatch on reconnect'),
    (Icons.video_file_rounded,
        'Evidence recording',
        'Encrypted locally, uploaded when online'),
    (Icons.lock_rounded,
        'Evidence vault',
        'AES-256 local storage, no internet needed'),
    (Icons.notifications_active_rounded,
        'Local alarm & vibration',
        'OS-level — works with airplane mode on'),
    (Icons.psychology_rounded,
        'DCS fusion score',
        'All 4 inference slots run on-device'),
    (Icons.battery_charging_full_rounded,
        'Heuristic fallback',
        'No-internet mode uses rule-based detection'),
  ];

  static const List<(IconData, String, String)> _onlineFeatures = [
    (Icons.send_rounded,
        'SOS backend dispatch',
        'POST /api/sos/trigger — queued when offline'),
    (Icons.location_on_rounded,
        'Live location share',
        'Real-time GPS stream to trusted contacts'),
    (Icons.people_alt_rounded,
        'Trusted contact alerts',
        'SMS + push notifications to contacts'),
    (Icons.cloud_upload_rounded,
        'Evidence upload',
        'Vault items synced to encrypted server store'),
    (Icons.map_rounded,
        'Heatmap contribution',
        'Anonymised DCS events feed the danger heatmap'),
    (Icons.system_update_alt_rounded,
        'OTA model updates',
        'New TFLite weights delivered without app update'),
    (Icons.verified_user_rounded,
        'Check-in reminder push',
        'Server-scheduled FCM notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = online ? _onlineFeatures : _offlineFeatures;
    final statusColor = online ? ZapColors.warning : ZapColors.safe;
    final statusIcon  = online ? Icons.cloud_rounded : Icons.check_circle_rounded;

    return ZapCard(
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, desc) = entry.value;
          return Column(
            children: [
              if (i > 0)
                Divider(
                  color: ZapColors.divider,
                  height: 1,
                  thickness: 1,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: ZapColors.textMuted, size: 16),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: ZapTypography.bodySmall.copyWith(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: ZapTypography.labelSmall.copyWith(
                                color: ZapColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(statusIcon, color: statusColor, size: 14),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Pending queue card ───────────────────────────────────────────────────────

/// Shows events queued for dispatch when connectivity returns.
///
/// Day 51 stub: the real queue manager (SQLite-backed) ships in Week 12+.
/// Today we surface the concept and the UI contract so the queue manager
/// can wire to this card without screen changes.
class _PendingQueueCard extends StatelessWidget {
  const _PendingQueueCard();

  // Stub counts — real queue service wires these in Week 12+.
  static const int _pendingSos          = 0;
  static const int _pendingLocationPts  = 0;
  static const int _pendingEvidenceItems = 0;

  @override
  Widget build(BuildContext context) {
    final total = _pendingSos + _pendingLocationPts + _pendingEvidenceItems;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                total > 0
                    ? Icons.pending_actions_rounded
                    : Icons.check_circle_outline_rounded,
                color: total > 0 ? ZapColors.warning : ZapColors.safe,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                total > 0
                    ? '$total item${total == 1 ? '' : 's'} queued'
                    : 'Queue empty — nothing pending',
                style: ZapTypography.labelMedium.copyWith(
                  color: total > 0 ? ZapColors.warning : ZapColors.safe,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          _QueueRow(
            icon: Icons.crisis_alert_rounded,
            label: 'SOS dispatches',
            count: _pendingSos,
            danger: true,
          ),
          _QueueRow(
            icon: Icons.location_on_rounded,
            label: 'Location points',
            count: _pendingLocationPts,
          ),
          _QueueRow(
            icon: Icons.video_file_rounded,
            label: 'Evidence items',
            count: _pendingEvidenceItems,
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            total > 0
                ? 'Items will be dispatched automatically when internet returns.'
                : 'All events have been dispatched to the server.',
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.icon,
    required this.label,
    required this.count,
    this.danger = false,
  });

  final IconData icon;
  final String   label;
  final int      count;
  final bool     danger;

  @override
  Widget build(BuildContext context) {
    final color = count > 0
        ? (danger ? ZapColors.danger : ZapColors.warning)
        : ZapColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary),
            ),
          ),
          Text(
            '$count',
            style: ZapTypography.labelSmall.copyWith(
              color: color,
              fontFamily: 'IBMPlexMono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Local storage card ───────────────────────────────────────────────────────

/// Approximate local storage used by ZapSafe's offline data.
///
/// Day 51 stub: reads a hardcoded breakdown. The real implementation
/// (scanning the vault + queue DB) ships alongside the evidence vault in
/// Day 81+.
class _LocalStorageCard extends StatelessWidget {
  const _LocalStorageCard();

  static const List<(String, double, Color)> _buckets = [
    ('Encrypted vault',  0.0,  ZapColors.info),
    ('Queued SOS data',  0.0,  ZapColors.danger),
    ('Model cache',      3.8,  ZapColors.warning),
    ('App data',         1.2,  ZapColors.textSecondary),
  ];

  double get _totalMb =>
      _buckets.fold(0, (sum, b) => sum + b.$2);

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total
          Row(
            children: [
              const Icon(Icons.storage_rounded,
                  color: ZapColors.textSecondary, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                '${_totalMb.toStringAsFixed(1)} MB used locally',
                style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          // Per-bucket bar
          ...(_buckets.map((b) {
            final (label, mb, color) = b;
            final frac = _totalMb > 0 ? (mb / _totalMb).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: ZapTypography.bodySmall.copyWith(
                              color: ZapColors.textSecondary),
                        ),
                      ),
                      Text(
                        '${mb.toStringAsFixed(1)} MB',
                        style: ZapTypography.labelSmall.copyWith(
                          color: color,
                          fontFamily: 'IBMPlexMono',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: frac < 0.02 ? 0.02 : frac,
                      backgroundColor: ZapColors.bgSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          color.withOpacity(0.6)),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          })),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Vault + queue totals update in Day 81 (evidence vault)',
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );
}
