/// Day 75 — DELIVERY CONFIRMATION Screen
///
/// Shows which emergency contacts received the SOS alert and when.
/// Uses GET /api/v1/sos/{id}/delivery-status/ built Day 75.
///
/// ── Features ──────────────────────────────────────────────────────────────
///   • Per-contact card showing push + SMS delivery status
///   • Colour-coded status: green=delivered, yellow=sent, red=failed, grey=pending
///   • Timestamps: sent_at, delivered_at, acked_at
///   • Acked badge: "Contact acknowledged ✓"
///   • Empty state: "No delivery data yet" for emulator testing
///   • Refresh button to re-fetch

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_config.dart';
import '../../core/theme/spacing.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  final String? sosId;
  const DeliveryConfirmationScreen({super.key, this.sosId});

  @override
  State<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _errorMsg;

  // Emulator mock data for testing without real SOS
  final List<Map<String, dynamic>> _mockContacts = [
    {
      'name': 'Priya Sharma',
      'phone': '+919876543210',
      'push': {'status': 'delivered', 'sent_at': '2026-05-28T10:00:00Z', 'delivered_at': '2026-05-28T10:00:03Z', 'acked_at': '2026-05-28T10:01:15Z'},
      'sms':  {'status': 'delivered', 'sent_at': '2026-05-28T10:00:01Z', 'delivered_at': '2026-05-28T10:00:08Z', 'acked_at': null},
    },
    {
      'name': 'Rahul Kumar',
      'phone': '+919123456789',
      'push': {'status': 'failed', 'sent_at': '2026-05-28T10:00:01Z', 'delivered_at': null, 'acked_at': null},
      'sms':  {'status': 'sent', 'sent_at': '2026-05-28T10:00:02Z', 'delivered_at': null, 'acked_at': null},
    },
    {
      'name': 'Anjali Singh',
      'phone': '+919988776655',
      'push': {'status': 'delivered', 'sent_at': '2026-05-28T10:00:01Z', 'delivered_at': '2026-05-28T10:00:05Z', 'acked_at': null},
      'sms':  null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDeliveryStatus();
  }

  Future<void> _loadDeliveryStatus() async {
    setState(() { _loading = true; _errorMsg = null; });
    final sosId = widget.sosId;
    if (sosId == null) {
      // Emulator: use mock data
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() { _contacts = _mockContacts; _loading = false; });
      return;
    }
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ));
      final res = await dio.get(
        '/api/v1/sos/$sosId/delivery-status/',
        options: Options(
          headers: {'Authorization': 'Bearer ${ApiConfig.devToken}'},
        ),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        setState(() => _contacts = List<Map<String, dynamic>>.from(data['contacts'] ?? []));
      } else {
        setState(() => _errorMsg = 'Failed to load delivery status.');
      }
    } catch (_) {
      setState(() {
        _contacts = _mockContacts;
        _errorMsg = 'Showing mock data (offline)';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'delivered': return const Color(0xFF22C55E);
      case 'sent':      return const Color(0xFFF59E0B);
      case 'failed':    return const Color(0xFFEF4444);
      case 'acked':     return const Color(0xFF6366F1);
      default:          return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'delivered': return Icons.done_all_rounded;
      case 'sent':      return Icons.done_rounded;
      case 'failed':    return Icons.error_outline_rounded;
      case 'acked':     return Icons.check_circle_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text(
          'Delivery Confirmation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9CA3AF)),
            onPressed: _loadDeliveryStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(
              children: [
                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg, vertical: 10),
                    color: const Color(0xFF1C1C1E),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                    ),
                  ),
                if (_contacts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_email_unread_outlined, color: Color(0xFF6B7280), size: 48),
                          SizedBox(height: ZapSpacing.md),
                          Text('No delivery data yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
                          SizedBox(height: 6),
                          Text('Trigger an SOS to see delivery status', style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(ZapSpacing.lg),
                      itemCount: _contacts.length,
                      itemBuilder: (ctx, i) => _buildContactCard(_contacts[i]),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final push = contact['push'] as Map<String, dynamic>?;
    final sms  = contact['sms']  as Map<String, dynamic>?;
    final bool acked = push?['acked_at'] != null || sms?['acked_at'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: acked
            ? Border.all(color: const Color(0xFF6366F1).withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF374151),
                    child: Text(
                      (contact['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact['name'] as String? ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        contact['phone'] as String? ?? '',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              if (acked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Acknowledged ✓',
                    style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF374151), height: 1),
          const SizedBox(height: 14),

          // Channel rows
          if (push != null) _buildChannelRow('Push', Icons.notifications_outlined, push),
          if (push != null && sms != null) const SizedBox(height: 10),
          if (sms != null) _buildChannelRow('SMS', Icons.sms_outlined, sms),
          if (push == null && sms == null)
            const Text('No notifications sent', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChannelRow(String channelLabel, IconData channelIcon, Map<String, dynamic> log) {
    final status = log['status'] as String?;
    final color = _statusColor(status);

    return Row(
      children: [
        Icon(channelIcon, color: const Color(0xFF9CA3AF), size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(channelLabel, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        const Spacer(),
        Icon(_statusIcon(status), color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (status ?? 'pending').toUpperCase(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Text(
              'Sent: ${_formatTime(log['sent_at'] as String?)}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
            ),
            if (log['delivered_at'] != null)
              Text(
                'Delivered: ${_formatTime(log['delivered_at'] as String?)}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10),
              ),
          ],
        ),
      ],
    );
  }
}
