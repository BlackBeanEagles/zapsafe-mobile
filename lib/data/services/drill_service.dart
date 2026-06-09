/// Day 60 — Drill Mode Service
///
/// POST /api/v1/drill/start/            → {drill_id}  (202)
/// GET  /api/v1/drill/{id}/results/     → [DrillResult]
/// GET  /api/v1/drill/history/?days=90  → [DrillHistory]
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class DrillContactResult {
  const DrillContactResult({
    required this.contactId,
    required this.contactName,
    required this.tier,
    required this.acked,
    required this.ackTimeMs,
  });

  final String contactId;
  final String contactName;
  final int    tier;
  final bool   acked;
  final int    ackTimeMs;

  factory DrillContactResult.fromJson(Map<String, dynamic> j) =>
      DrillContactResult(
        contactId:   j['contact_id']   as String,
        contactName: j['contact_name'] as String,
        tier:        (j['tier']        as num).toInt(),
        acked:       j['acked']        as bool,
        ackTimeMs:   (j['ack_time_ms'] as num).toInt(),
      );
}

class DrillResult {
  const DrillResult({
    required this.completed,
    required this.contactResults,
    required this.protectionScoreBefore,
    required this.protectionScoreAfter,
    required this.weakestLink,
    required this.recommendation,
  });

  final bool                   completed;
  final List<DrillContactResult> contactResults;
  final int                    protectionScoreBefore;
  final int                    protectionScoreAfter;
  final String                 weakestLink;
  final String                 recommendation;

  int get scoreDelta => protectionScoreAfter - protectionScoreBefore;

  factory DrillResult.fromJson(Map<String, dynamic> j) => DrillResult(
        completed:             j['completed'] as bool,
        contactResults:        (j['contact_results'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(DrillContactResult.fromJson)
            .toList(),
        protectionScoreBefore: (j['protection_score_before'] as num).toInt(),
        protectionScoreAfter:  (j['protection_score_after']  as num).toInt(),
        weakestLink:           (j['weakest_link']   as String?) ?? '',
        recommendation:        (j['recommendation'] as String?) ?? '',
      );
}

class DrillHistoryItem {
  const DrillHistoryItem({
    required this.id,
    required this.startedAt,
    required this.status,
    required this.avgResponseMs,
    required this.scoreDelta,
  });

  final String   id;
  final DateTime startedAt;
  final String   status;
  final int?     avgResponseMs;   // null if no contacts responded
  final int      scoreDelta;

  factory DrillHistoryItem.fromJson(Map<String, dynamic> j) => DrillHistoryItem(
        id:          j['id'] as String,
        startedAt:   DateTime.parse(j['started_at'] as String).toLocal(),
        status:      j['status'] as String,
        avgResponseMs: j['avg_response_ms'] == null
            ? null
            : (j['avg_response_ms'] as num).toInt(),
        scoreDelta: (j['score_delta'] as num?)?.toInt() ?? 0,
      );
}

class DrillHistory {
  const DrillHistory({
    required this.count,
    required this.days,
    required this.drills,
  });

  final int                 count;
  final int                 days;
  final List<DrillHistoryItem> drills;

  static const empty = DrillHistory(count: 0, days: 90, drills: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

class DrillService {
  const DrillService(this._client);
  final ApiClient _client;

  /// POST /api/v1/drill/start/ — initiates a practice SOS drill.
  ///
  /// Returns the [drill_id] UUID on success (202).
  Future<String> start({
    bool includeTier1       = true,
    bool includeTier2       = true,
    bool simulateEscalation = true,
  }) async {
    final r = await _client.dio.post<Map<String, dynamic>>(
      ApiConfig.drillStart,
      data: {
        'include_tier1':       includeTier1,
        'include_tier2':       includeTier2,
        'simulate_escalation': simulateEscalation,
      },
    );
    return r.data!['drill_id'] as String;
  }

  /// GET /api/v1/drill/{id}/results/ — fetch completed drill results.
  Future<DrillResult> fetchResults(String drillId) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      '/api/v1/drill/$drillId/results/',
    );
    return DrillResult.fromJson(r.data!);
  }

  /// GET /api/v1/drill/history/?days=<n>
  Future<DrillHistory> fetchHistory({int days = 90}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.drillHistory,
      queryParameters: {'days': days},
    );
    final data = r.data;
    if (data == null) return DrillHistory.empty;
    final raw = (data['drills'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return DrillHistory(
      count: (data['count'] as int?) ?? raw.length,
      days:  (data['days']  as int?) ?? days,
      drills: raw.map(DrillHistoryItem.fromJson).toList(),
    );
  }
}
