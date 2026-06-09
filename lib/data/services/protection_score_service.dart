/// Day 59 — Protection Score Service
///
/// GET /api/v1/protection-score/         → [ProtectionScoreResult]
/// GET /api/v1/protection-score/history/ → [ScoreHistory]
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class ScoreComponent {
  const ScoreComponent({
    required this.key,
    required this.label,
    required this.score,
    required this.maxScore,
    required this.complete,
  });

  final String key;
  final String label;
  final int    score;
  final int    maxScore;
  final bool   complete;

  factory ScoreComponent.fromJson(Map<String, dynamic> j) => ScoreComponent(
        key:      j['key']      as String,
        label:    j['label']    as String,
        score:    (j['score']     as num).toInt(),
        maxScore: (j['max_score'] as num).toInt(),
        complete: j['complete'] as bool,
      );
}

class NextAction {
  const NextAction({
    required this.key,
    required this.description,
    required this.impact,
  });

  final String key;
  final String description;
  final int    impact;

  factory NextAction.fromJson(Map<String, dynamic> j) => NextAction(
        key:         j['key']         as String,
        description: j['description'] as String,
        impact:      (j['impact'] as num).toInt(),
      );
}

class ProtectionScoreResult {
  const ProtectionScoreResult({
    required this.score,
    required this.band,
    required this.lastUpdated,
    required this.breakdown,
    required this.nextActions,
  });

  final int                  score;
  final String               band;          // critical|low|moderate|good|strong|maximum
  final DateTime             lastUpdated;
  final List<ScoreComponent> breakdown;
  final List<NextAction>     nextActions;

  factory ProtectionScoreResult.fromJson(Map<String, dynamic> j) =>
      ProtectionScoreResult(
        score:      (j['score'] as num).toInt(),
        band:       j['band'] as String,
        lastUpdated: DateTime.parse(j['last_updated'] as String).toLocal(),
        breakdown:  (j['breakdown'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ScoreComponent.fromJson)
            .toList(),
        nextActions: (j['next_actions'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(NextAction.fromJson)
            .toList(),
      );
}

class ScoreSnapshot {
  const ScoreSnapshot({
    required this.snapshotDate,
    required this.score,
    required this.delta,
    required this.triggeringEvent,
  });

  final DateTime snapshotDate;
  final int      score;
  final int      delta;
  final String   triggeringEvent;

  factory ScoreSnapshot.fromJson(Map<String, dynamic> j) => ScoreSnapshot(
        snapshotDate: DateTime.parse(j['snapshot_date'] as String),
        score:        (j['score'] as num).toInt(),
        delta:        (j['delta'] as num).toInt(),
        triggeringEvent: (j['triggering_event'] as String?) ?? '',
      );
}

class ScoreHistory {
  const ScoreHistory({
    required this.count,
    required this.days,
    required this.snapshots,
  });

  final int                count;
  final int                days;
  final List<ScoreSnapshot> snapshots;

  static const empty = ScoreHistory(count: 0, days: 30, snapshots: []);
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ProtectionScoreService {
  const ProtectionScoreService(this._client);
  final ApiClient _client;

  /// GET /api/v1/protection-score/ — always recalculates server-side.
  Future<ProtectionScoreResult> fetch() async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.protectionScore,
    );
    return ProtectionScoreResult.fromJson(r.data!);
  }

  /// GET /api/v1/protection-score/history/?days=<n>
  Future<ScoreHistory> fetchHistory({int days = 30}) async {
    final r = await _client.dio.get<Map<String, dynamic>>(
      ApiConfig.protectionScoreHistory,
      queryParameters: {'days': days},
    );
    final data = r.data;
    if (data == null) return ScoreHistory.empty;
    final raw = (data['snapshots'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return ScoreHistory(
      count:     (data['count'] as int?) ?? raw.length,
      days:      (data['days']  as int?) ?? days,
      snapshots: raw.map(ScoreSnapshot.fromJson).toList(),
    );
  }
}
