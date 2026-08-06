/// Premium subscription (Razorpay) service — backend Day 91-100, wired
/// for real Day 303.
///
/// POST /api/v1/subscription/create/   — start Razorpay checkout
/// GET  /api/v1/subscription/status/   — current plan + limits
/// POST /api/v1/subscription/cancel/   — cancel at period end
///
/// Response shapes match `subscription/serializers.py` on the real backend,
/// verified by reading the serializer + view source directly (Docker was
/// unavailable in this sandbox — code-level verification, not a live round
/// trip; see DAY301_305_INTEGRATION_WIRING.md).
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

enum SubscriptionPlan {
  free('free'),
  premium('premium'),
  premiumPlus('premium_plus');

  const SubscriptionPlan(this.apiValue);
  final String apiValue;

  static SubscriptionPlan fromApi(String v) => SubscriptionPlan.values.firstWhere(
        (p) => p.apiValue == v,
        orElse: () => SubscriptionPlan.free,
      );
}

class CheckoutResult {
  const CheckoutResult({required this.razorpaySubscriptionId, required this.checkoutUrl});
  final String razorpaySubscriptionId;
  final String checkoutUrl;

  factory CheckoutResult.fromJson(Map<String, dynamic> j) => CheckoutResult(
        razorpaySubscriptionId: j['razorpay_subscription_id'] as String? ?? '',
        checkoutUrl: j['checkout_url'] as String? ?? '',
      );
}

class SubscriptionStatus {
  const SubscriptionStatus({
    required this.plan,
    required this.status,
    required this.createdAt,
    required this.nextBillingDate,
    required this.amountMonthly,
    required this.contactLimit,
    required this.storageLimitMb,
    required this.storageUsedBytes,
    required this.smsPriority,
    required this.hasPremiumBenefits,
  });

  final SubscriptionPlan plan;
  final String status;
  final DateTime? createdAt;
  final DateTime? nextBillingDate;
  final int amountMonthly;

  /// null == unlimited (premium/premium_plus). 3 for free tier.
  final int? contactLimit;
  final int storageLimitMb;
  final int storageUsedBytes;
  final String smsPriority; // normal | high
  final bool hasPremiumBenefits;

  bool get isPremium => plan != SubscriptionPlan.free;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> j) => SubscriptionStatus(
        plan: SubscriptionPlan.fromApi(j['plan'] as String? ?? 'free'),
        status: j['status'] as String? ?? 'inactive',
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
        nextBillingDate: j['next_billing_date'] != null
            ? DateTime.tryParse(j['next_billing_date'] as String)
            : null,
        amountMonthly: (j['amount_monthly'] as num?)?.toInt() ?? 0,
        contactLimit: (j['contact_limit'] as num?)?.toInt(),
        storageLimitMb: (j['storage_limit_mb'] as num?)?.toInt() ?? 0,
        storageUsedBytes: (j['storage_used_bytes'] as num?)?.toInt() ?? 0,
        smsPriority: j['sms_priority'] as String? ?? 'normal',
        hasPremiumBenefits: (j['has_premium_benefits'] as bool?) ?? false,
      );

  /// Free-tier default shown before the first real API response arrives.
  static const fallback = SubscriptionStatus(
    plan: SubscriptionPlan.free,
    status: 'inactive',
    createdAt: null,
    nextBillingDate: null,
    amountMonthly: 0,
    contactLimit: 3,
    storageLimitMb: 100,
    storageUsedBytes: 0,
    smsPriority: 'normal',
    hasPremiumBenefits: false,
  );
}

class CancelResult {
  const CancelResult({required this.status, required this.accessUntil});
  final String status;
  final DateTime? accessUntil;

  factory CancelResult.fromJson(Map<String, dynamic> j) => CancelResult(
        status: j['status'] as String? ?? 'canceled',
        accessUntil:
            j['access_until'] != null ? DateTime.tryParse(j['access_until'] as String) : null,
      );
}

class PremiumSubscriptionService {
  const PremiumSubscriptionService(this._client);
  final ApiClient _client;

  /// POST /api/v1/subscription/create/
  Future<CheckoutResult> createCheckout({
    SubscriptionPlan plan = SubscriptionPlan.premium,
  }) async {
    final res = await _client.dio.post(
      ApiConfig.subscriptionCreate,
      data: {'plan': plan.apiValue},
    );
    return CheckoutResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /api/v1/subscription/status/
  Future<SubscriptionStatus> fetchStatus() async {
    final res = await _client.dio.get(ApiConfig.subscriptionStatus);
    return SubscriptionStatus.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/subscription/cancel/
  Future<CancelResult> cancel() async {
    final res = await _client.dio.post(ApiConfig.subscriptionCancel);
    return CancelResult.fromJson(res.data as Map<String, dynamic>);
  }
}
