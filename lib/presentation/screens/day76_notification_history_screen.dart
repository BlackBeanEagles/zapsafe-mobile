/// Day 76 — NOTIFICATION HISTORY Screen
///
/// Timeline of all past notifications (push + SMS) for the user.
/// Uses GET /api/v1/notifications/history/ endpoint built Day 76.
///
/// ── Features ──────────────────────────────────────────────────────────────
///   • Timeline list: newest first
///   • Filter tabs: All | Push | SMS
///   • Status badge: delivered / sent / failed / acked
///   • Title + body preview
///   • Timestamp (sent_at)
///   • Linked SOS event badge (if sos_event_id present)
///   • Empty state per filter tab
///   • Pull-to-refresh
///
/// Day 367: requests go through ApiClient (real JWT with refresh, pinned
/// client). This used a raw Dio with ApiConfig.devToken, a fake token the
/// backend rejects, so it ALWAYS fell back to a fabricated SOS history with
/// invented contacts and "delivered" badges. Failures are now reported and
/// the list stays empty; the sample rows are gone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/auth_providers.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends ConsumerState<NotificationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({String? channel}) async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final queryParams = channel != null ? {'channel': channel} : null;
      final res = await ref.read(apiClientProvider).dio.get<Map<String, dynamic>>(
            '/api/v1/notifications/history/',
            queryParameters: queryParams,
          );
      final data = res.data;
      if (res.statusCode == 200 && data != null) {
        setState(() => _all = List<Map<String, dynamic>>.from(data['results'] ?? []));
      } else {
        setState(() {
          _all = const [];
          _errorMsg = 'Could not load notification history (HTTP ${res.statusCode}).';
        });
      }
    } catch (e) {
      // NO sample fallback: a made-up history of SOS alerts "delivered" to
      // named contacts is the one thing this screen must never show.
      setState(() {
        _all = const [];
        _errorMsg = "Couldn't load notification history. $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filtered(String? channel) {
    if (channel == null) return _all;
    return _all.where((n) => n['channel'] == channel).toList();
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'delivered': return const Color(0xFF22C55E);
      case 'sent':      return const Color(0xFFF59E0B);
      case 'failed':    return const Color(0xFFEF4444);
      case 'acked':     return const Color(0xFF6366F1);
      default:          return const Color(0xFF6B7280);
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} $h:$m';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text(
          'Notification History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF6B7280),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Push'),
            Tab(text: 'SMS'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(
              children: [
                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
                    color: const Color(0xFF1C1C1E),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(null),
                      _buildList('push'),
                      _buildList('sms'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildList(String? channel) {
    final items = _filtered(channel);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              channel == 'sms' ? Icons.sms_outlined : Icons.notifications_none_outlined,
              color: const Color(0xFF4B5563),
              size: 48,
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'No ${channel ?? ''} notifications yet',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadHistory(channel: channel),
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _buildNotifCard(items[i]),
      ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    final status = notif['status'] as String?;
    final channel = notif['channel'] as String?;
    final hasSosLink = notif['sos_event_id'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Channel Icon
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  channel == 'sms' ? Icons.sms_outlined : Icons.notifications_outlined,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif['title'] as String? ?? 'Notification',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'To: ${notif['recipient_name'] as String? ?? notif['recipient_phone']}',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (status ?? 'pending').toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    _formatDateTime(notif['sent_at'] as String?),
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            notif['body'] as String? ?? '',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasSosLink) ...[
            const SizedBox(height: ZapSpacing.sm),
            const Row(
              children: [
                Icon(Icons.link_rounded, color: Color(0xFF6366F1), size: 13),
                SizedBox(width: ZapSpacing.xs),
                Text(
                  'Linked to SOS event',
                  style: TextStyle(color: Color(0xFF6366F1), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
