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

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_config.dart';
import '../../core/theme/spacing.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _errorMsg;

  // Emulator mock data
  final List<Map<String, dynamic>> _mockHistory = [
    {
      'id': '1', 'recipient_phone': '+919876543210', 'recipient_name': 'Priya Sharma',
      'channel': 'push', 'status': 'delivered', 'title': 'SOS Alert — Priya needs help!',
      'body': 'Priya has triggered an SOS. Open to view location.',
      'sent_at': '2026-05-28T10:00:00Z', 'delivered_at': '2026-05-28T10:00:03Z',
      'acked_at': '2026-05-28T10:01:15Z', 'sos_event_id': 'abc-123', 'error_message': '',
    },
    {
      'id': '2', 'recipient_phone': '+919876543210', 'recipient_name': 'Priya Sharma',
      'channel': 'sms', 'status': 'delivered', 'title': 'ZapSafe SOS',
      'body': 'EMERGENCY: Priya has triggered SOS. Track: https://zapsafe.me/t/abc123',
      'sent_at': '2026-05-28T10:00:01Z', 'delivered_at': '2026-05-28T10:00:08Z',
      'acked_at': null, 'sos_event_id': 'abc-123', 'error_message': '',
    },
    {
      'id': '3', 'recipient_phone': '+919123456789', 'recipient_name': 'Rahul Kumar',
      'channel': 'push', 'status': 'failed', 'title': 'SOS Alert',
      'body': 'Push delivery failed.',
      'sent_at': '2026-05-28T09:00:00Z', 'delivered_at': null,
      'acked_at': null, 'sos_event_id': 'abc-123', 'error_message': 'FCM token expired',
    },
    {
      'id': '4', 'recipient_phone': '+919876543210', 'recipient_name': 'Priya Sharma',
      'channel': 'push', 'status': 'sent', 'title': '🔋 Battery Warning',
      'body': 'Priya\'s battery is at 18%. Check in.',
      'sent_at': '2026-05-27T15:30:00Z', 'delivered_at': null,
      'acked_at': null, 'sos_event_id': null, 'error_message': '',
    },
    {
      'id': '5', 'recipient_phone': '+919988776655', 'recipient_name': 'Anjali Singh',
      'channel': 'sms', 'status': 'delivered', 'title': 'ZapSafe Check-in Reminder',
      'body': 'Your check-in timer expired. Are you safe?',
      'sent_at': '2026-05-26T20:00:00Z', 'delivered_at': '2026-05-26T20:00:10Z',
      'acked_at': null, 'sos_event_id': null, 'error_message': '',
    },
  ];

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
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ));
      final queryParams = channel != null ? {'channel': channel} : null;
      final res = await dio.get(
        '/api/v1/notifications/history/',
        queryParameters: queryParams,
        options: Options(
          headers: {'Authorization': 'Bearer ${ApiConfig.devToken}'},
        ),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        setState(() => _all = List<Map<String, dynamic>>.from(data['results'] ?? []));
      } else {
        setState(() { _all = _mockHistory; _errorMsg = 'Showing mock data'; });
      }
    } catch (_) {
      setState(() { _all = _mockHistory; _errorMsg = 'Offline — showing mock data'; });
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
            Row(
              children: const [
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
