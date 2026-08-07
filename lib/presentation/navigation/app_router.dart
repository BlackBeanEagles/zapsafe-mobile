import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/otp_verify_screen.dart';
import '../screens/auth/phone_entry_screen.dart';
import '../screens/day1_project_setup_screen.dart';
import '../screens/day5_navigation_index_screen.dart';
import '../screens/day6_auth_foundation_screen.dart';
import '../screens/day9_jwt_storage_screen.dart';
import '../screens/day10_auth_review_screen.dart';
import '../screens/day11_permissions_screen.dart';
import '../screens/day13_device_tier_screen.dart';
import '../screens/day14_feature_flags_screen.dart';
import '../screens/day15_week3_review_screen.dart';
import '../screens/day16_push_notifications_screen.dart';
import '../screens/day17_push_routing_screen.dart';
import '../screens/day18_drills_and_schedule_screen.dart';
import '../screens/day19_month1_integration_screen.dart';
import '../screens/day20_month1_review_screen.dart';
import '../screens/day21_background_service_screen.dart';
import '../screens/day22_watchdog_screen.dart';
import '../screens/day23_platform_channels_screen.dart';
import '../screens/day24_lp4_watchdog_screen.dart';
import '../screens/day25_week5_review_screen.dart';
import '../screens/day26_audio_capture_screen.dart';
import '../screens/day27_audio_features_screen.dart';
import '../screens/day28_ios_audio_screen.dart';
import '../screens/day29_inference_screen.dart';
import '../screens/day30_week6_review_screen.dart';
import '../screens/day31_tflite_models_screen.dart';
import '../screens/day32_dcs_engine_screen.dart';
import '../screens/day33_dcs_stream_screen.dart';
import '../screens/day34_isolate_latency_screen.dart';
import '../screens/day35_week7_review_screen.dart';
import '../screens/day36_imu_service_screen.dart';
import '../screens/day37_gps_service_screen.dart';
import '../screens/day38_fallback_and_state_screen.dart';
import '../screens/day39_state_wiring_screen.dart';
import '../screens/day40_month2_review_screen.dart';
import '../screens/day41_onboarding_step1_screen.dart';
import '../screens/day42_onboarding_step2_screen.dart';
import '../screens/day43_onboarding_step3_screen.dart';
import '../screens/day44_onboarding_step4_screen.dart';
import '../screens/day45_onboarding_step5_screen.dart';
import '../screens/day44_heuristic_engine_screen.dart';
import '../screens/day45_model_bundle_screen.dart';
import '../screens/day46_detection_settings_screen.dart';
import '../screens/day47_integration_tests_screen.dart';
import '../screens/day48_device_diagnostics_screen.dart';
import '../screens/day49_audio_pipeline_screen.dart';
import '../screens/day50_motion_validation_screen.dart';
import '../screens/day51_offline_status_screen.dart';
import '../screens/day52_phone_capability_screen.dart';
import '../screens/day53_compatibility_matrix_screen.dart';
import '../screens/day54_capability_report_screen.dart';
import '../screens/day55_detection_event_screen.dart';
import '../screens/day56_model_download_screen.dart';
import '../screens/day57_ml_analytics_screen.dart';
import '../screens/day58_safe_zone_screen.dart';
import '../screens/day59_protection_score_screen.dart';
import '../screens/day60_drill_screen.dart';
import '../screens/day61_inference_log_screen.dart';
import '../screens/day62_incident_screen.dart';
import '../screens/day63_alert_threshold_screen.dart';
import '../screens/day64_escalation_screen.dart';
import '../screens/day65_check_in_screen.dart';
import '../screens/day66_sos_template_screen.dart';
import '../screens/day67_notification_pref_screen.dart';
import '../screens/day68_audit_log_screen.dart';
import '../screens/day69_data_export_screen.dart';
import '../screens/day70_privacy_screen.dart';
import '../screens/day71_alert_pending_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/placeholder/contacts_placeholder.dart';
import '../screens/placeholder/dashboard_placeholder.dart';
import '../screens/placeholder/onboarding_placeholder.dart';
import '../screens/placeholder/settings_placeholder.dart';
import '../screens/day73_do_not_disturb_screen.dart';     // Day 73
import '../screens/day75_delivery_confirmation_screen.dart'; // Day 75
import '../screens/day76_notification_history_screen.dart';  // Day 76 (history)
import '../screens/day76_sos_active_screen.dart';         // Day 76-79
import '../screens/day77_alert_dashboard_screen.dart';    // Day 77-78
import '../screens/day80_alert_dashboard_screen.dart';    // Day 80
import '../screens/day81_settings_screen.dart';           // Day 81
import '../screens/day82_evidence_vault_screen.dart';     // Day 82
import '../screens/day83_contact_management_screen.dart'; // Day 83
import '../screens/day84_emergency_drills_screen.dart';   // Day 84
import '../screens/day85_alert_thresholds_screen.dart';   // Day 85
import '../screens/day86_escalation_policy_screen.dart';  // Day 86
import '../screens/day87_sos_templates_screen.dart';      // Day 87
import '../screens/day88_notification_history_screen.dart'; // Day 88
import '../screens/day89_activity_audit_log_screen.dart';   // Day 89
import '../screens/day90_data_privacy_screen.dart';         // Day 90
import '../screens/day91_premium_subscription_screen.dart'; // Day 91-92
import '../screens/day92_premium_features_screen.dart';    // Day 92-93
import '../screens/day93_subscription_management_screen.dart'; // Day 93-94
import '../screens/day94_payment_methods_screen.dart';        // Day 94-95
import '../screens/day95_billing_history_screen.dart';        // Day 95-96
import '../screens/day96_language_settings_screen.dart';      // Day 96-97
import '../screens/day97_accessibility_settings_screen.dart'; // Day 97
import '../screens/day98_profile_account_screen.dart';        // Day 98
import '../screens/day99_help_support_screen.dart';           // Day 99
import '../screens/day100_milestone_screen.dart';             // Day 100
import '../screens/day101_i18n_setup_screen.dart';            // Day 101
import '../screens/day102_translation_demo_screen.dart';      // Day 102
import '../screens/day103_translation_coverage_screen.dart';  // Day 103
import '../screens/day104_onboarding_i18n_screen.dart';       // Day 104
import '../screens/day105_month3_i18n_screen.dart';           // Day 105
import '../screens/day106_detection_flow_screen.dart';        // Day 106
import '../screens/day107_month4_i18n_screen.dart';           // Day 107
import '../screens/day108_language_toggle_screen.dart';       // Day 108
import '../screens/day109_semantics_screen.dart';             // Day 109
import '../screens/day110_a11y_contrast_screen.dart';         // Day 110
import '../screens/day111_beta_flavor_screen.dart';           // Day 111
import '../screens/day112_beta_onboarding_screen.dart';       // Day 112
import '../screens/day113_feedback_fab_screen.dart';          // Day 113
import '../screens/day114_feedback_form_screen.dart';         // Day 114
import '../screens/day115_false_positive_screen.dart';        // Day 115
import '../screens/day116_sentry_setup_screen.dart';          // Day 116
import '../screens/day117_testflight_screen.dart';            // Day 117
import '../screens/day118_android_distribution_screen.dart';  // Day 118
import '../screens/day119_release_notes_screen.dart';         // Day 119
import '../screens/day120_beta_launch_screen.dart';           // Day 120
import '../screens/day121_feedback_analysis_screen.dart';     // Day 121
import '../screens/day122_crash_fixes_screen.dart';           // Day 122-123
import '../screens/day123_hotfix_release_screen.dart';        // Day 123
import '../screens/day124_false_positive_fix_screen.dart';    // Day 124
import '../screens/day125_fp_verify_screen.dart';             // Day 125
import '../screens/day126_ui_bugs_screen.dart';               // Day 126
import '../screens/day127_notification_fixes_screen.dart';    // Day 127
import '../screens/day128_contact_delivery_screen.dart';      // Day 128
import '../screens/day129_performance_screen.dart';           // Day 129
import '../screens/day130_memory_screen.dart';                // Day 130
import '../screens/day131_memory_leaks_screen.dart';          // Day 131
import '../screens/day132_leak_verify_screen.dart';           // Day 132
import '../screens/day133_onboarding_simplify_screen.dart';   // Day 133
import '../screens/day134_onboarding_polish_screen.dart';     // Day 134
import '../screens/day135_release_bundle_screen.dart';        // Day 135
import '../screens/day136_feedback_round2_screen.dart';       // Day 136
import '../screens/day137_iteration_decision_screen.dart';    // Day 137
import '../screens/day138_final_polish_screen.dart';          // Day 138
import '../screens/day139_security_review_screen.dart';       // Day 139
import '../screens/day140_beta_final_screen.dart';            // Day 140
import '../screens/day141_app_size_screen.dart';              // Day 141
import '../screens/day142_model_compress_screen.dart';        // Day 142
import '../screens/day143_lazy_load_screen.dart';             // Day 143
import '../screens/day144_asset_optimise_screen.dart';        // Day 144
import '../screens/day145_cold_start_screen.dart';            // Day 145
import '../screens/day146_aws_url_screen.dart';               // Day 146
import '../screens/day147_aws_test_screen.dart';              // Day 147
import '../screens/day148_aws_issues_screen.dart';            // Day 148
import '../screens/day149_regression_test_screen.dart';       // Day 149
import '../screens/day150_production_release_screen.dart';    // Day 150
import '../screens/day151_privacy_policy_screen.dart';        // Day 151-152
import '../screens/day152_policy_consent_screen.dart';        // Day 152
import '../screens/day153_terms_of_service_screen.dart';      // Day 153-154
import '../screens/day154_legal_hub_screen.dart';             // Day 154
import '../screens/day155_consent_management_screen.dart';    // Day 155-157
import '../screens/day156_consent_gates_screen.dart';         // Day 156
import '../screens/day157_privacy_settings_screen.dart';      // Day 157
import '../screens/day158_permissions_screen.dart';           // Day 158-160
import '../screens/day159_permission_flow_screen.dart';        // Day 159
import '../screens/day160_permission_recovery_screen.dart';    // Day 160
import '../screens/day161_consent_gate_screen.dart';           // Day 161-162
import '../screens/day162_consent_flow_tests_screen.dart';     // Day 162
import '../screens/day163_analytics_prefs_screen.dart';        // Day 163-165
import '../screens/day164_data_safety_screen.dart';            // Day 164
import '../screens/day165_analytics_hub_screen.dart';          // Day 165
import '../screens/day166_data_export_request_screen.dart';    // Day 166
import '../screens/day167_data_export_download_screen.dart';   // Day 167
import '../screens/day168_data_export_edge_cases_screen.dart'; // Day 168
import '../screens/day169_account_deletion_request_screen.dart'; // Day 169
import '../screens/day170_account_deletion_grace_screen.dart';  // Day 170
import '../screens/day171_account_deletion_final_screen.dart';  // Day 171
import '../screens/day172_account_deletion_edge_cases_screen.dart'; // Day 172
import '../screens/day173_data_access_audit_screen.dart';          // Day 173
import '../screens/day174_data_access_audit_detail_screen.dart';   // Day 174
import '../screens/day175_third_party_access_screen.dart';         // Day 175
import '../screens/day176_data_retention_settings_screen.dart';    // Day 176
import '../screens/day177_data_retention_scheduler_screen.dart';   // Day 177
import '../screens/day178_data_retention_edge_cases_screen.dart';  // Day 178
import '../screens/day179_active_sessions_screen.dart';            // Day 179
import '../screens/day180_session_security_screen.dart';           // Day 180
import '../screens/day181_cert_pinning_screen.dart';               // Day 181
import '../screens/day182_network_security_screen.dart';           // Day 182
import '../screens/day183_biometric_lock_screen.dart';             // Day 183
import '../screens/day184_biometric_hardening_screen.dart';        // Day 184
import '../screens/day185_root_detection_screen.dart';             // Day 185
import '../screens/day186_tamper_alert_screen.dart';               // Day 186
import '../screens/day187_secure_storage_screen.dart';             // Day 187
import '../screens/day188_key_rotation_screen.dart';               // Day 188
import '../screens/day189_security_dashboard_screen.dart';         // Day 189
import '../screens/day190_section_c_complete_screen.dart';         // Day 190
import '../screens/day191_screenshots_screen.dart';                // Day 191
import '../screens/day192_screenshot_frames_screen.dart';          // Day 192
import '../screens/day193_store_listing_screen.dart';              // Day 193
import '../screens/day194_store_listing_extra_screen.dart';        // Day 194
import '../screens/day195_privacy_compliance_screen.dart';         // Day 195
import '../screens/day196_privacy_alignment_screen.dart';          // Day 196
import '../screens/day197_release_checklist_screen.dart';          // Day 197
import '../screens/day198_qa_pass_screen.dart';                    // Day 198
import '../screens/day199_final_submission_screen.dart';           // Day 199
import '../screens/day200_grand_finale_screen.dart';               // Day 200
import '../screens/day301_backend_integration_audit_screen.dart';  // Day 301
import '../screens/day302_analytics_live_wire_screen.dart';        // Day 302
import '../screens/day303_razorpay_live_wire_screen.dart';         // Day 303
import '../screens/day304_delivery_status_live_wire_screen.dart';  // Day 304
import '../screens/day305_accept_language_wire_screen.dart';       // Day 305
import '../screens/day306_notification_tiers_polish_screen.dart';  // Day 306
import '../screens/day307_sos_longpress_ring_screen.dart';         // Day 307
import '../screens/day308_persistent_status_card_screen.dart';     // Day 308
import '../screens/day309_evidence_vault_search_screen.dart';      // Day 309
import '../screens/day310_section_f_milestone_screen.dart';        // Day 310
import '../screens/day311_eu_emergency_numbers_screen.dart';       // Day 311
import '../screens/day312_latam_emergency_numbers_screen.dart';    // Day 312
import '../screens/day313_sea_emergency_numbers_screen.dart';      // Day 313
import '../screens/day314_play_store_eu_listing_screen.dart';      // Day 314
import '../screens/day315_app_store_eu_listing_screen.dart';       // Day 315
import '../screens/day316_play_staged_rollout_screen.dart';        // Day 316
import '../screens/day317_app_store_phased_release_screen.dart';   // Day 317
import '../screens/day318_regional_pricing_matrix_screen.dart';    // Day 318
import '../screens/day319_gdpr_consent_wire_screen.dart';          // Day 319
import '../screens/day320_section_g_milestone_screen.dart';        // Day 320
import '../screens/day321_sos_trigger_refactor_screen.dart';       // Day 321
import '../screens/day322_dcs_pipeline_wire_screen.dart';          // Day 322
import '../screens/day323_journey_ml_confidence_screen.dart';      // Day 323
import '../screens/day324_release_candidate_manifest_screen.dart'; // Day 324
import '../screens/day325_ota_model_update_screen.dart';           // Day 325
import '../screens/day326_cold_start_report_screen.dart';          // Day 326
import '../screens/day327_memory_leak_tracker_screen.dart';        // Day 327
import '../screens/day328_battery_monitoring_production_screen.dart'; // Day 328
import '../screens/day329_false_positive_tuning_production_screen.dart'; // Day 329
import '../screens/day330_section_h_rc_milestone_screen.dart';     // Day 330
import '../screens/placeholder/vault_placeholder.dart';

/// Provider that holds whether the user has finished onboarding.
///
/// In production, this is hydrated from secure storage on app start. For now
/// it defaults to `true` so we can land on the dashboard during development.
final isOnboardedProvider = StateProvider<bool>((ref) => true);

/// Canonical route paths — referenced everywhere via `AppRoutes.dashboard`
/// rather than raw strings.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
  static const sosActive = '/sos-active';
  static const vault = '/vault';
  static const contacts = '/contacts';
  static const settings = '/settings';
  static const day1 = '/day1';                       // Day 1 — Project Setup
  static const day9 = '/day9';                       // Day 9 — JWT Storage
  static const day10 = '/day10';                     // Day 10 — Auth Review
  static const day6 = '/day6';
  static const phoneEntry = '/phone-entry';
  static const otpVerify = '/otp-verify';
  static const permissions = '/permissions';
  static const deviceTier = '/device-tier';
  static const onboardingPermissions = '/onboarding/permissions';
  static const featureFlags = '/feature-flags';
  static const week3Review = '/week3-review';
  static const pushNotifications = '/push';
  static const pushRouting = '/push-routing';
  static const drillsSchedule = '/drills-schedule';
  static const month1Integration = '/month1-integration';
  static const month1Review = '/month1-review';
  static const backgroundEngine = '/background-engine';
  static const watchdog = '/watchdog';
  static const platformChannels = '/platform-channels';
  static const lp4Watchdog = '/lp4-watchdog';
  static const week5Review = '/week5-review';
  static const audioCapture = '/audio-capture';
  static const audioFeatures = '/audio-features';
  static const iosAudio = '/ios-audio';
  static const inference = '/inference';
  static const week6Review = '/week6-review';
  static const tfliteModels = '/tflite-models';
  static const dcsEngine = '/dcs-engine';
  static const dcsStream = '/dcs-stream';
  static const isolateLatency = '/isolate-latency';
  static const week7Review = '/week7-review';
  static const imuService = '/imu-service';
  static const gpsService = '/gps-service';
  static const day38FallbackAndState = '/day38';
  static const day39StateWiring = '/day39';
  static const month2Review = '/month2-review';
  static const onboardingStep1 = '/onboarding/step1';
  static const onboardingStep2 = '/onboarding/step2';
  static const onboardingStep3 = '/onboarding/step3';
  static const onboardingStep4 = '/onboarding/step4';
  static const onboardingStep5       = '/onboarding/step5';
  static const heuristicEngine      = '/heuristic-engine';   // Day 44
  static const modelBundle          = '/model-bundle';        // Day 45
  static const detectionSettings    = '/detection-settings'; // Day 46
  static const integrationTests     = '/day47-integration-tests'; // Day 47
  static const deviceDiagnostics    = '/device-diagnostics';      // Day 48
  static const audioPipeline        = '/audio-pipeline';           // Day 49
  static const motionValidation     = '/motion-validation';        // Day 50
  static const offlineStatus        = '/offline-status';            // Day 51
  static const phoneCapability      = '/phone-capability';          // Day 52
  static const compatibilityMatrix  = '/compatibility-matrix';      // Day 53
  static const capabilityReport     = '/capability-report';          // Day 54
  static const detectionEvents      = '/detection-events';           // Day 55
  static const modelDownloads       = '/model-downloads';             // Day 56
  static const mlAnalytics          = '/ml-analytics';                // Day 57
  static const safeZones            = '/safe-zones';                   // Day 58
  static const protectionScore      = '/protection-score';              // Day 59
  static const drillMode            = '/drill-mode';                    // Day 60
  static const inferenceLog         = '/inference-log';                  // Day 61
  static const incidentReport       = '/incident-report';                // Day 62
  static const alertThresholds      = '/alert-thresholds';               // Day 63
  static const escalationPolicies  = '/escalation-policies';            // Day 64
  static const checkIns            = '/check-ins';                       // Day 65
  static const sosTemplates        = '/sos-templates';                   // Day 66
  static const notificationPrefs  = '/notification-prefs';              // Day 67
  static const auditLog           = '/audit-log';                        // Day 68
  static const dataExport         = '/data-export';                      // Day 69
  static const privacy            = '/privacy';                           // Day 70
  static const alertPending       = '/alert-pending';                     // Day 71
  static const doNotDisturb      = '/do-not-disturb';                     // Day 73
  static const deliveryConfirmation = '/delivery-confirmation';           // Day 75
  static const notificationHistory  = '/notification-history';            // Day 76
  static const alertDashboard    = '/alert-dashboard';                    // Day 77-78
  static const alertDashboardV2  = '/alert-dashboard-v2';                 // Day 80
  static const settingsV2        = '/settings-v2';                         // Day 81
  static const evidenceVault     = '/evidence-vault';                       // Day 82
  static const contactsV2        = '/contacts-v2';                          // Day 83
  static const emergencyDrills   = '/emergency-drills';                      // Day 84
  static const alertThresholdsV2  = '/alert-thresholds-v2';                  // Day 85
  static const escalationPoliciesV2 = '/escalation-policies-v2';             // Day 86
  static const sosTemplatesV2        = '/sos-templates-v2';                   // Day 87
  static const notificationHistoryV2 = '/notification-history-v2';             // Day 88
  static const activityAuditLogV2    = '/activity-audit-log-v2';               // Day 89
  static const dataPrivacyV2         = '/data-privacy-v2';                     // Day 90
  static const premiumSubscription   = '/premium-subscription';                 // Day 91-92
  static const premiumFeatures        = '/premium-features';                     // Day 92-93
  static const subscriptionMgmt      = '/subscription-management';               // Day 93-94
  static const paymentMethods        = '/payment-methods';                       // Day 94-95
  static const billingHistory        = '/billing-history';                       // Day 95-96
  static const languageSettings      = '/language-settings';                      // Day 96-97
  static const accessibilitySettings = '/accessibility-settings';                  // Day 97
  static const profileAccount         = '/profile-account';                         // Day 98
  static const helpSupport            = '/help-support';                             // Day 99
  static const milestone              = '/milestone';                                 // Day 100
  static const i18nSetup              = '/i18n-setup';                                // Day 101
  static const translationDemo        = '/translation-demo';                          // Day 102
  static const translationCoverage    = '/translation-coverage';                      // Day 103
  static const onboardingI18n         = '/onboarding-i18n';                            // Day 104
  static const month3I18n             = '/month3-i18n';                                 // Day 105
  static const detectionFlow          = '/detection-flow';                               // Day 106
  static const month4I18n             = '/month4-i18n';                                 // Day 107
  static const languageToggle         = '/language-toggle';                              // Day 108
  static const semanticsA11y          = '/semantics-a11y';                               // Day 109
  static const a11yContrast           = '/a11y-contrast';                                 // Day 110
  static const betaFlavor             = '/beta-flavor';                                   // Day 111
  static const betaOnboarding         = '/beta-onboarding';                               // Day 112
  static const feedbackFab            = '/feedback-fab';                                  // Day 113
  static const feedbackForm           = '/feedback-form';                                 // Day 114
  static const falsePositive          = '/false-positive';                                // Day 115
  static const sentrySetup            = '/sentry-setup';                                  // Day 116
  static const testFlight             = '/testflight';                                    // Day 117
  static const androidDist            = '/android-dist';                                  // Day 118
  static const releaseNotes           = '/release-notes';                                 // Day 119
  static const betaLaunch             = '/beta-launch';                                   // Day 120
  static const feedbackAnalysis       = '/feedback-analysis';                             // Day 121
  static const crashFixes             = '/crash-fixes';                                   // Day 122-123
  static const hotfixRelease          = '/hotfix-release';                                // Day 123
  static const falsePositiveFix       = '/false-positive-fix';                            // Day 124
  static const fpVerify               = '/fp-verify';                                     // Day 125
  static const uiBugs                 = '/ui-bugs';                                       // Day 126
  static const notificationFixes      = '/notification-fixes';                            // Day 127
  static const contactDelivery        = '/contact-delivery';                              // Day 128
  static const performance            = '/performance';                                   // Day 129
  static const memoryOpt              = '/memory-opt';                                    // Day 130
  static const memoryLeaks            = '/memory-leaks';                                  // Day 131
  static const leakVerify             = '/leak-verify';                                   // Day 132
  static const onboardingSimplify     = '/onboarding-simplify';                           // Day 133
  static const onboardingPolish       = '/onboarding-polish';                              // Day 134
  static const releaseBundle          = '/release-bundle';                                 // Day 135
  static const feedbackRound2         = '/feedback-round2';                                // Day 136
  static const iterationDecision      = '/iteration-decision';                             // Day 137
  static const finalPolish            = '/final-polish';                                   // Day 138
  static const securityReview        = '/security-review';                                // Day 139
  static const betaFinal             = '/beta-final';                                     // Day 140
  static const appSizeAudit          = '/app-size-audit';                                 // Day 141
  static const modelCompress         = '/model-compress';                                  // Day 142
  static const lazyLoad              = '/lazy-load';                                       // Day 143
  static const assetOptimise         = '/asset-optimise';                                  // Day 144
  static const coldStart             = '/cold-start';                                      // Day 145
  static const awsUrl                = '/aws-url';                                         // Day 146
  static const awsTest               = '/aws-test';                                        // Day 147
  static const awsIssues             = '/aws-issues';                                      // Day 148
  static const regressionTest        = '/regression-test';                                 // Day 149
  static const productionRelease     = '/production-release';                              // Day 150
  static const privacyPolicy         = '/privacy-policy';                                  // Day 151-152
  static const policyConsent         = '/policy-consent';                                  // Day 152
  static const termsOfService        = '/terms-of-service';                                // Day 153-154
  static const legalHub              = '/legal-hub';                                       // Day 154
  static const consentManagement     = '/consent-management';                              // Day 155-157
  static const consentGates          = '/consent-gates';                                   // Day 156
  static const privacySettings       = '/privacy-settings';                                // Day 157
  static const appPermissions        = '/app-permissions';                                 // Day 158-160
  static const permissionFlow        = '/permission-flow';                                 // Day 159
  static const permissionRecovery    = '/permission-recovery';                             // Day 160
  static const consentGate           = '/consent-gate';                                    // Day 161-162
  static const consentFlowTests      = '/consent-flow-tests';                              // Day 162
  static const analyticsPrefs        = '/analytics-prefs';                                 // Day 163-165
  static const dataSafety            = '/data-safety';                                     // Day 164
  static const analyticsHub          = '/analytics-hub';                                   // Day 165
  static const dataExportRequest    = '/data-export-request';                              // Day 166
  static const dataExportDownload   = '/data-export-download';                             // Day 167
  static const dataExportEdgeCases  = '/data-export-edge-cases';                           // Day 168
  static const accountDeletionRequest = '/account-deletion-request';                       // Day 169
  static const accountDeletionGrace   = '/account-deletion-grace';                         // Day 170
  static const accountDeletionFinal     = '/account-deletion-final';                       // Day 171
  static const accountDeletionEdgeCases = '/account-deletion-edge-cases';                 // Day 172
  static const dataAccessAudit          = '/data-access-audit';                           // Day 173
  static const dataAccessAuditDetail    = '/data-access-audit-detail';                    // Day 174
  static const thirdPartyAccess         = '/third-party-access';                          // Day 175
  static const dataRetentionSettings    = '/data-retention-settings';                     // Day 176
  static const dataRetentionScheduler   = '/data-retention-scheduler';                    // Day 177
  static const dataRetentionEdgeCases   = '/data-retention-edge-cases';                   // Day 178
  static const activeSessions           = '/active-sessions';                              // Day 179
  static const sessionSecurity          = '/session-security';                             // Day 180
  static const certPinning              = '/cert-pinning';                                 // Day 181
  static const networkSecurity          = '/network-security';                             // Day 182
  static const biometricLock            = '/biometric-lock';                               // Day 183
  static const biometricHardening       = '/biometric-hardening';                          // Day 184
  static const rootDetection            = '/root-detection';                               // Day 185
  static const tamperAlert              = '/tamper-alert';                                 // Day 186
  static const secureStorage            = '/secure-storage';                               // Day 187
  static const keyRotation              = '/key-rotation';                                 // Day 188
  static const securityDashboard        = '/security-dashboard';                           // Day 189
  static const sectionCComplete         = '/section-c-complete';                           // Day 190
  static const screenshots              = '/screenshots';                                  // Day 191
  static const screenshotFrames         = '/screenshot-frames';                            // Day 192
  static const storeListing             = '/store-listing';                                // Day 193
  static const storeListingExtra        = '/store-listing-extra';                          // Day 194
  static const privacyCompliance        = '/privacy-compliance';                           // Day 195
  static const privacyAlignment         = '/privacy-alignment';                            // Day 196
  static const releaseChecklist         = '/release-checklist';                            // Day 197
  static const qaPass                   = '/qa-pass';                                      // Day 198
  static const finalSubmission          = '/final-submission';                             // Day 199
  static const grandFinale              = '/grand-finale';                                 // Day 200

  // ─── Section F: Production Wiring (Days 301-305) ────────────────────────
  static const integrationAudit         = '/day-301-integration-audit';                    // Day 301
  static const analyticsLiveWire        = '/day-302-analytics-live-wire';                  // Day 302
  static const razorpayLiveWire         = '/day-303-razorpay-live-wire';                   // Day 303
  static const deliveryStatusLiveWire   = '/day-304-delivery-status-live-wire';             // Day 304
  static const acceptLanguageWire       = '/day-305-accept-language-wire';                 // Day 305

  // ─── Section F: Production Wiring (Days 306-310) ────────────────────────
  static const notificationTiersPolish  = '/day-306-notification-tiers-polish';           // Day 306
  static const sosLongPressRingPolish   = '/day-307-sos-longpress-ring-polish';            // Day 307
  static const statusCardPolish         = '/day-308-status-card-polish';                   // Day 308
  static const evidenceVaultSearchPolish = '/day-309-evidence-vault-search-polish';        // Day 309
  static const sectionFMilestone        = '/day-310-section-f-milestone';                  // Day 310

  // ─── Section G: Global Store Expansion (Days 311-320) ────────────────────
  static const euEmergencyNumbers       = '/day-311-eu-emergency-numbers';                 // Day 311
  static const latamEmergencyNumbers    = '/day-312-latam-emergency-numbers';              // Day 312
  static const seaEmergencyNumbers      = '/day-313-sea-emergency-numbers';                // Day 313
  static const playStoreEuListing       = '/day-314-play-store-eu-listing';                // Day 314
  static const appStoreEuListing        = '/day-315-app-store-eu-listing';                 // Day 315
  static const playStagedRollout        = '/day-316-play-staged-rollout';                  // Day 316
  static const appStorePhasedRelease    = '/day-317-app-store-phased-release';              // Day 317
  static const regionalPricingMatrix    = '/day-318-regional-pricing-matrix';               // Day 318
  static const gdprConsentWire          = '/day-319-gdpr-consent-wire';                     // Day 319
  static const sectionGMilestone        = '/day-320-section-g-milestone';                   // Day 320

  // ─── Section H: v9.2 Core & RC (Days 321-330) ────────────────────────────
  static const sosTriggerRefactor       = '/day-321-sos-trigger-refactor';                 // Day 321
  static const dcsPipelineWire          = '/day-322-dcs-pipeline-wire';                    // Day 322
  static const journeyMlConfidence      = '/day-323-journey-ml-confidence';                // Day 323
  static const releaseCandidateManifest = '/day-324-release-candidate-manifest';           // Day 324
  static const otaModelUpdate           = '/day-325-ota-model-update';                     // Day 325
  static const coldStartReport          = '/day-326-cold-start-report';                    // Day 326
  static const memoryLeakTracker        = '/day-327-memory-leak-tracker';                  // Day 327
  static const batteryMonitoringProd    = '/day-328-battery-monitoring-production';        // Day 328
  static const falsePositiveTuningProd  = '/day-329-false-positive-tuning-production';     // Day 329
  static const sectionHMilestone        = '/day-330-section-h-rc-milestone';               // Day 330
}

/// Builds the [GoRouter] used by `MaterialApp.router`.
///
/// Watches [isOnboardedProvider] so unauthenticated users always get pushed
/// to /onboarding regardless of which deep link they came in on.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isOnboarded = ref.read(isOnboardedProvider);
      final loggingIn = state.matchedLocation == AppRoutes.onboarding;

      // Not onboarded → force onboarding screen
      if (!isOnboarded && !loggingIn) return AppRoutes.onboarding;

      // Onboarded but on /onboarding → bounce to dashboard
      if (isOnboarded && loggingIn) return AppRoutes.dashboard;

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Day5NavigationIndexScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.sosActive,
        builder: (context, state) => const Day76SosActiveScreen(), // Day 76
      ),
      GoRoute(
        path: AppRoutes.alertDashboard,
        builder: (context, state) => const Day77AlertDashboardScreen(), // Day 77-78
      ),
      GoRoute(
        path: AppRoutes.alertDashboardV2,
        builder: (context, state) => const Day80AlertDashboardScreen(), // Day 80
      ),
      GoRoute(
        path: AppRoutes.settingsV2,
        builder: (context, state) => const Day81SettingsScreen(), // Day 81
      ),
      GoRoute(
        path: AppRoutes.evidenceVault,
        builder: (context, state) => const Day82EvidenceVaultScreen(), // Day 82
      ),
      GoRoute(
        path: AppRoutes.contactsV2,
        builder: (context, state) => const Day83ContactManagementScreen(), // Day 83
      ),
      GoRoute(
        path: AppRoutes.emergencyDrills,
        builder: (context, state) => const Day84EmergencyDrillsScreen(),   // Day 84
      ),
      GoRoute(
        path: AppRoutes.alertThresholdsV2,
        builder: (context, state) => const Day85AlertThresholdsScreen(),   // Day 85
      ),
      GoRoute(
        path: AppRoutes.escalationPoliciesV2,
        builder: (context, state) => const Day86EscalationPolicyScreen(),  // Day 86
      ),
      GoRoute(
        path: AppRoutes.sosTemplatesV2,
        builder: (context, state) => const Day87SosTemplatesScreen(),      // Day 87
      ),
      GoRoute(
        path: AppRoutes.notificationHistoryV2,
        builder: (context, state) =>
            const Day88NotificationHistoryScreen(),                          // Day 88
      ),
      GoRoute(
        path: AppRoutes.activityAuditLogV2,
        builder: (context, state) =>
            const Day89ActivityAuditLogScreen(),                             // Day 89
      ),
      GoRoute(
        path: AppRoutes.dataPrivacyV2,
        builder: (context, state) =>
            const Day90DataPrivacyScreen(),                                  // Day 90
      ),
      GoRoute(
        path: AppRoutes.premiumSubscription,
        builder: (context, state) =>
            const Day91PremiumSubscriptionScreen(),                          // Day 91-92
      ),
      GoRoute(
        path: AppRoutes.premiumFeatures,
        builder: (context, state) =>
            const Day92PremiumFeaturesScreen(),                              // Day 92-93
      ),
      GoRoute(
        path: AppRoutes.subscriptionMgmt,
        builder: (context, state) =>
            const Day93SubscriptionManagementScreen(),                       // Day 93-94
      ),
      GoRoute(
        path: AppRoutes.paymentMethods,
        builder: (context, state) =>
            const Day94PaymentMethodsScreen(),                               // Day 94-95
      ),
      GoRoute(
        path: AppRoutes.billingHistory,
        builder: (context, state) =>
            const Day95BillingHistoryScreen(),                               // Day 95-96
      ),
      GoRoute(
        path: AppRoutes.languageSettings,
        builder: (context, state) =>
            const Day96LanguageSettingsScreen(),                             // Day 96-97
      ),
      GoRoute(
        path: AppRoutes.accessibilitySettings,
        builder: (context, state) =>
            const Day97AccessibilitySettingsScreen(),                        // Day 97
      ),
      GoRoute(
        path: AppRoutes.profileAccount,
        builder: (context, state) =>
            const Day98ProfileAccountScreen(),                               // Day 98
      ),
      GoRoute(
        path: AppRoutes.helpSupport,
        builder: (context, state) =>
            const Day99HelpSupportScreen(),                                  // Day 99
      ),
      GoRoute(
        path: AppRoutes.milestone,
        builder: (context, state) =>
            const Day100MilestoneScreen(),                                   // Day 100
      ),
      GoRoute(
        path: AppRoutes.i18nSetup,
        builder: (context, state) =>
            const Day101I18nSetupScreen(),                                   // Day 101
      ),
      GoRoute(
        path: AppRoutes.translationDemo,
        builder: (context, state) =>
            const Day102TranslationDemoScreen(),                             // Day 102
      ),
      GoRoute(
        path: AppRoutes.translationCoverage,
        builder: (context, state) =>
            const Day103TranslationCoverageScreen(),                         // Day 103
      ),
      GoRoute(
        path: AppRoutes.onboardingI18n,
        builder: (context, state) =>
            const Day104OnboardingI18nScreen(),                              // Day 104
      ),
      GoRoute(
        path: AppRoutes.month3I18n,
        builder: (context, state) =>
            const Day105Month3I18nScreen(),                                  // Day 105
      ),
      GoRoute(
        path: AppRoutes.detectionFlow,
        builder: (context, state) =>
            const Day106DetectionFlowScreen(),                               // Day 106
      ),
      GoRoute(
        path: AppRoutes.month4I18n,
        builder: (context, state) =>
            const Day107Month4I18nScreen(),                                  // Day 107
      ),
      GoRoute(
        path: AppRoutes.languageToggle,
        builder: (context, state) =>
            const Day108LanguageToggleScreen(),                              // Day 108
      ),
      GoRoute(
        path: AppRoutes.semanticsA11y,
        builder: (context, state) =>
            const Day109SemanticsScreen(),                                   // Day 109
      ),
      GoRoute(
        path: AppRoutes.a11yContrast,
        builder: (context, state) =>
            const Day110A11yContrastScreen(),                                // Day 110
      ),
      GoRoute(
        path: AppRoutes.betaFlavor,
        builder: (context, state) =>
            const Day111BetaFlavorScreen(),                                  // Day 111
      ),
      GoRoute(
        path: AppRoutes.betaOnboarding,
        builder: (context, state) =>
            const Day112BetaOnboardingScreen(),                              // Day 112
      ),
      GoRoute(
        path: AppRoutes.feedbackFab,
        builder: (context, state) =>
            const Day113FeedbackFabScreen(),                                 // Day 113
      ),
      GoRoute(
        path: AppRoutes.feedbackForm,
        builder: (context, state) =>
            const Day114FeedbackFormScreen(),                                // Day 114
      ),
      GoRoute(
        path: AppRoutes.falsePositive,
        builder: (context, state) =>
            const Day115FalsePositiveScreen(),                               // Day 115
      ),
      GoRoute(
        path: AppRoutes.sentrySetup,
        builder: (context, state) =>
            const Day116SentrySetupScreen(),                                 // Day 116
      ),
      GoRoute(
        path: AppRoutes.testFlight,
        builder: (context, state) =>
            const Day117TestFlightScreen(),                                  // Day 117
      ),
      GoRoute(
        path: AppRoutes.androidDist,
        builder: (context, state) =>
            const Day118AndroidDistributionScreen(),                         // Day 118
      ),
      GoRoute(
        path: AppRoutes.releaseNotes,
        builder: (context, state) =>
            const Day119ReleaseNotesScreen(),                                // Day 119
      ),
      GoRoute(
        path: AppRoutes.betaLaunch,
        builder: (context, state) =>
            const Day120BetaLaunchScreen(),                                  // Day 120
      ),
      GoRoute(
        path: AppRoutes.feedbackAnalysis,
        builder: (context, state) =>
            const Day121FeedbackAnalysisScreen(),                            // Day 121
      ),
      GoRoute(
        path: AppRoutes.crashFixes,
        builder: (context, state) =>
            const Day122CrashFixesScreen(),                                  // Day 122-123
      ),
      GoRoute(
        path: AppRoutes.hotfixRelease,
        builder: (context, state) =>
            const Day123HotfixReleaseScreen(),                               // Day 123
      ),
      GoRoute(
        path: AppRoutes.falsePositiveFix,
        builder: (context, state) =>
            const Day124FalsePositiveFixScreen(),                            // Day 124
      ),
      GoRoute(
        path: AppRoutes.fpVerify,
        builder: (context, state) =>
            const Day125FpVerifyScreen(),                                    // Day 125
      ),
      GoRoute(
        path: AppRoutes.uiBugs,
        builder: (context, state) =>
            const Day126UiBugsScreen(),                                      // Day 126
      ),
      GoRoute(
        path: AppRoutes.notificationFixes,
        builder: (context, state) =>
            const Day127NotificationFixesScreen(),                           // Day 127
      ),
      GoRoute(
        path: AppRoutes.contactDelivery,
        builder: (context, state) =>
            const Day128ContactDeliveryScreen(),                             // Day 128
      ),
      GoRoute(
        path: AppRoutes.performance,
        builder: (context, state) =>
            const Day129PerformanceScreen(),                                 // Day 129
      ),
      GoRoute(
        path: AppRoutes.memoryOpt,
        builder: (context, state) =>
            const Day130MemoryScreen(),                                      // Day 130
      ),
      GoRoute(
        path: AppRoutes.memoryLeaks,
        builder: (context, state) =>
            const Day131MemoryLeaksScreen(),                                 // Day 131
      ),
      GoRoute(
        path: AppRoutes.leakVerify,
        builder: (context, state) =>
            const Day132LeakVerifyScreen(),                                  // Day 132
      ),
      GoRoute(
        path: AppRoutes.onboardingSimplify,
        builder: (context, state) =>
            const Day133OnboardingSimplifyScreen(),                          // Day 133
      ),
      GoRoute(
        path: AppRoutes.onboardingPolish,
        builder: (context, state) =>
            const Day134OnboardingPolishScreen(),                            // Day 134
      ),
      GoRoute(
        path: AppRoutes.releaseBundle,
        builder: (context, state) =>
            const Day135ReleaseBundleScreen(),                               // Day 135
      ),
      GoRoute(
        path: AppRoutes.feedbackRound2,
        builder: (context, state) =>
            const Day136FeedbackRound2Screen(),                              // Day 136
      ),
      GoRoute(
        path: AppRoutes.iterationDecision,
        builder: (context, state) =>
            const Day137IterationDecisionScreen(),                           // Day 137
      ),
      GoRoute(
        path: AppRoutes.finalPolish,
        builder: (context, state) =>
            const Day138FinalPolishScreen(),                                 // Day 138
      ),
      GoRoute(
        path: AppRoutes.securityReview,
        builder: (context, state) =>
            const Day139SecurityReviewScreen(),                              // Day 139
      ),
      GoRoute(
        path: AppRoutes.betaFinal,
        builder: (context, state) =>
            const Day140BetaFinalScreen(),                                   // Day 140
      ),
      GoRoute(
        path: AppRoutes.appSizeAudit,
        builder: (context, state) =>
            const Day141AppSizeScreen(),                                     // Day 141
      ),
      GoRoute(
        path: AppRoutes.modelCompress,
        builder: (context, state) =>
            const Day142ModelCompressScreen(),                               // Day 142
      ),
      GoRoute(
        path: AppRoutes.lazyLoad,
        builder: (context, state) =>
            const Day143LazyLoadScreen(),                                    // Day 143
      ),
      GoRoute(
        path: AppRoutes.assetOptimise,
        builder: (context, state) =>
            const Day144AssetOptimiseScreen(),                               // Day 144
      ),
      GoRoute(
        path: AppRoutes.coldStart,
        builder: (context, state) =>
            const Day145ColdStartScreen(),                                   // Day 145
      ),
      GoRoute(
        path: AppRoutes.awsUrl,
        builder: (context, state) =>
            const Day146AwsUrlScreen(),                                      // Day 146
      ),
      GoRoute(
        path: AppRoutes.awsTest,
        builder: (context, state) =>
            const Day147AwsTestScreen(),                                     // Day 147
      ),
      GoRoute(
        path: AppRoutes.awsIssues,
        builder: (context, state) =>
            const Day148AwsIssuesScreen(),                                   // Day 148
      ),
      GoRoute(
        path: AppRoutes.regressionTest,
        builder: (context, state) =>
            const Day149RegressionTestScreen(),                              // Day 149
      ),
      GoRoute(
        path: AppRoutes.productionRelease,
        builder: (context, state) =>
            const Day150ProductionReleaseScreen(),                           // Day 150
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) =>
            const Day151PrivacyPolicyScreen(),                               // Day 151-152
      ),
      GoRoute(
        path: AppRoutes.policyConsent,
        builder: (context, state) =>
            const Day152PolicyConsentScreen(),                               // Day 152
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        builder: (context, state) =>
            const Day153TermsOfServiceScreen(),                              // Day 153-154
      ),
      GoRoute(
        path: AppRoutes.legalHub,
        builder: (context, state) =>
            const Day154LegalHubScreen(),                                    // Day 154
      ),
      GoRoute(
        path: AppRoutes.consentManagement,
        builder: (context, state) =>
            const Day155ConsentManagementScreen(),                           // Day 155-157
      ),
      GoRoute(
        path: AppRoutes.consentGates,
        builder: (context, state) =>
            const Day156ConsentGatesScreen(),                                // Day 156
      ),
      GoRoute(
        path: AppRoutes.privacySettings,
        builder: (context, state) =>
            const Day157PrivacySettingsScreen(),                             // Day 157
      ),
      GoRoute(
        path: AppRoutes.appPermissions,
        builder: (context, state) =>
            const Day158PermissionsScreen(),                                 // Day 158-160
      ),
      GoRoute(
        path: AppRoutes.permissionFlow,
        builder: (context, state) =>
            const Day159PermissionFlowScreen(),                              // Day 159
      ),
      GoRoute(
        path: AppRoutes.permissionRecovery,
        builder: (context, state) =>
            const Day160PermissionRecoveryScreen(),                          // Day 160
      ),
      GoRoute(
        path: AppRoutes.consentGate,
        builder: (context, state) =>
            const Day161ConsentGateScreen(),                                 // Day 161-162
      ),
      GoRoute(
        path: AppRoutes.consentFlowTests,
        builder: (context, state) =>
            const Day162ConsentFlowTestsScreen(),                            // Day 162
      ),
      GoRoute(
        path: AppRoutes.analyticsPrefs,
        builder: (context, state) =>
            const Day163AnalyticsPrefsScreen(),                              // Day 163-165
      ),
      GoRoute(
        path: AppRoutes.dataSafety,
        builder: (context, state) =>
            const Day164DataSafetyScreen(),                                  // Day 164
      ),
      GoRoute(
        path: AppRoutes.analyticsHub,
        builder: (context, state) =>
            const Day165AnalyticsHubScreen(),                                // Day 165
      ),
      GoRoute(
        path: AppRoutes.dataExportRequest,
        builder: (context, state) =>
            const Day166DataExportRequestScreen(),                           // Day 166
      ),
      GoRoute(
        path: AppRoutes.dataExportDownload,
        builder: (context, state) =>
            const Day167DataExportDownloadScreen(),                          // Day 167
      ),
      GoRoute(
        path: AppRoutes.dataExportEdgeCases,
        builder: (context, state) =>
            const Day168DataExportEdgeCasesScreen(),                         // Day 168
      ),
      GoRoute(
        path: AppRoutes.accountDeletionRequest,
        builder: (context, state) =>
            const Day169AccountDeletionRequestScreen(),                       // Day 169
      ),
      GoRoute(
        path: AppRoutes.accountDeletionGrace,
        builder: (context, state) =>
            const Day170AccountDeletionGraceScreen(),                         // Day 170
      ),
      GoRoute(
        path: AppRoutes.accountDeletionFinal,
        builder: (context, state) =>
            const Day171AccountDeletionFinalScreen(),                         // Day 171
      ),
      GoRoute(
        path: AppRoutes.accountDeletionEdgeCases,
        builder: (context, state) =>
            const Day172AccountDeletionEdgeCasesScreen(),                     // Day 172
      ),
      GoRoute(
        path: AppRoutes.dataAccessAudit,
        builder: (context, state) =>
            const Day173DataAccessAuditScreen(),                              // Day 173
      ),
      GoRoute(
        path: AppRoutes.dataAccessAuditDetail,
        builder: (context, state) =>
            const Day174DataAccessAuditDetailScreen(),                        // Day 174
      ),
      GoRoute(
        path: AppRoutes.thirdPartyAccess,
        builder: (context, state) =>
            const Day175ThirdPartyAccessScreen(),                             // Day 175
      ),
      GoRoute(
        path: AppRoutes.dataRetentionSettings,
        builder: (context, state) =>
            const Day176DataRetentionSettingsScreen(),                        // Day 176
      ),
      GoRoute(
        path: AppRoutes.dataRetentionScheduler,
        builder: (context, state) =>
            const Day177DataRetentionSchedulerScreen(),                       // Day 177
      ),
      GoRoute(
        path: AppRoutes.dataRetentionEdgeCases,
        builder: (context, state) =>
            const Day178DataRetentionEdgeCasesScreen(),                       // Day 178
      ),
      GoRoute(
        path: AppRoutes.activeSessions,
        builder: (context, state) =>
            const Day179ActiveSessionsScreen(),                               // Day 179
      ),
      GoRoute(
        path: AppRoutes.sessionSecurity,
        builder: (context, state) =>
            const Day180SessionSecurityScreen(),                              // Day 180
      ),
      GoRoute(
        path: AppRoutes.certPinning,
        builder: (context, state) =>
            const Day181CertPinningScreen(),                                  // Day 181
      ),
      GoRoute(
        path: AppRoutes.networkSecurity,
        builder: (context, state) =>
            const Day182NetworkSecurityScreen(),                              // Day 182
      ),
      GoRoute(
        path: AppRoutes.biometricLock,
        builder: (context, state) =>
            const Day183BiometricLockScreen(),                                // Day 183
      ),
      GoRoute(
        path: AppRoutes.biometricHardening,
        builder: (context, state) =>
            const Day184BiometricHardeningScreen(),                           // Day 184
      ),
      GoRoute(
        path: AppRoutes.rootDetection,
        builder: (context, state) =>
            const Day185RootDetectionScreen(),                                // Day 185
      ),
      GoRoute(
        path: AppRoutes.tamperAlert,
        builder: (context, state) =>
            const Day186TamperAlertScreen(),                                  // Day 186
      ),
      GoRoute(
        path: AppRoutes.secureStorage,
        builder: (context, state) =>
            const Day187SecureStorageScreen(),                                // Day 187
      ),
      GoRoute(
        path: AppRoutes.keyRotation,
        builder: (context, state) =>
            const Day188KeyRotationScreen(),                                  // Day 188
      ),
      GoRoute(
        path: AppRoutes.securityDashboard,
        builder: (context, state) =>
            const Day189SecurityDashboardScreen(),                            // Day 189
      ),
      GoRoute(
        path: AppRoutes.sectionCComplete,
        builder: (context, state) =>
            const Day190SectionCCompleteScreen(),                             // Day 190
      ),
      GoRoute(
        path: AppRoutes.screenshots,
        builder: (context, state) =>
            const Day191ScreenshotsScreen(),                                  // Day 191
      ),
      GoRoute(
        path: AppRoutes.screenshotFrames,
        builder: (context, state) =>
            const Day192ScreenshotFramesScreen(),                             // Day 192
      ),
      GoRoute(
        path: AppRoutes.storeListing,
        builder: (context, state) =>
            const Day193StoreListingScreen(),                                 // Day 193
      ),
      GoRoute(
        path: AppRoutes.storeListingExtra,
        builder: (context, state) =>
            const Day194StoreListingExtraScreen(),                            // Day 194
      ),
      GoRoute(
        path: AppRoutes.privacyCompliance,
        builder: (context, state) =>
            const Day195PrivacyComplianceScreen(),                            // Day 195
      ),
      GoRoute(
        path: AppRoutes.privacyAlignment,
        builder: (context, state) =>
            const Day196PrivacyAlignmentScreen(),                             // Day 196
      ),
      GoRoute(
        path: AppRoutes.releaseChecklist,
        builder: (context, state) =>
            const Day197ReleaseChecklistScreen(),                             // Day 197
      ),
      GoRoute(
        path: AppRoutes.qaPass,
        builder: (context, state) =>
            const Day198QaPassScreen(),                                       // Day 198
      ),
      GoRoute(
        path: AppRoutes.finalSubmission,
        builder: (context, state) =>
            const Day199FinalSubmissionScreen(),                              // Day 199
      ),
      GoRoute(
        path: AppRoutes.grandFinale,
        builder: (context, state) =>
            const Day200GrandFinaleScreen(),                                  // Day 200 🏆
      ),
      GoRoute(
        path: AppRoutes.integrationAudit,
        builder: (context, state) =>
            const Day301BackendIntegrationAuditScreen(),                      // Day 301
      ),
      GoRoute(
        path: AppRoutes.analyticsLiveWire,
        builder: (context, state) =>
            const Day302AnalyticsLiveWireScreen(),                            // Day 302
      ),
      GoRoute(
        path: AppRoutes.razorpayLiveWire,
        builder: (context, state) =>
            const Day303RazorpayLiveWireScreen(),                             // Day 303
      ),
      GoRoute(
        path: AppRoutes.deliveryStatusLiveWire,
        builder: (context, state) =>
            const Day304DeliveryStatusLiveWireScreen(),                       // Day 304
      ),
      GoRoute(
        path: AppRoutes.acceptLanguageWire,
        builder: (context, state) =>
            const Day305AcceptLanguageWireScreen(),                           // Day 305
      ),
      GoRoute(
        path: AppRoutes.notificationTiersPolish,
        builder: (context, state) =>
            const Day306NotificationTiersPolishScreen(),                      // Day 306
      ),
      GoRoute(
        path: AppRoutes.sosLongPressRingPolish,
        builder: (context, state) =>
            const Day307SosLongpressRingScreen(),                             // Day 307
      ),
      GoRoute(
        path: AppRoutes.statusCardPolish,
        builder: (context, state) =>
            const Day308PersistentStatusCardScreen(),                         // Day 308
      ),
      GoRoute(
        path: AppRoutes.evidenceVaultSearchPolish,
        builder: (context, state) =>
            const Day309EvidenceVaultSearchScreen(),                          // Day 309
      ),
      GoRoute(
        path: AppRoutes.sectionFMilestone,
        builder: (context, state) =>
            const Day310SectionFMilestoneScreen(),                            // Day 310
      ),
      GoRoute(
        path: AppRoutes.euEmergencyNumbers,
        builder: (context, state) =>
            const Day311EuEmergencyNumbersScreen(),                           // Day 311
      ),
      GoRoute(
        path: AppRoutes.latamEmergencyNumbers,
        builder: (context, state) =>
            const Day312LatamEmergencyNumbersScreen(),                        // Day 312
      ),
      GoRoute(
        path: AppRoutes.seaEmergencyNumbers,
        builder: (context, state) =>
            const Day313SeaEmergencyNumbersScreen(),                          // Day 313
      ),
      GoRoute(
        path: AppRoutes.playStoreEuListing,
        builder: (context, state) =>
            const Day314PlayStoreEuListingScreen(),                           // Day 314
      ),
      GoRoute(
        path: AppRoutes.appStoreEuListing,
        builder: (context, state) =>
            const Day315AppStoreEuListingScreen(),                            // Day 315
      ),
      GoRoute(
        path: AppRoutes.playStagedRollout,
        builder: (context, state) =>
            const Day316PlayStagedRolloutScreen(),                            // Day 316
      ),
      GoRoute(
        path: AppRoutes.appStorePhasedRelease,
        builder: (context, state) =>
            const Day317AppStorePhasedReleaseScreen(),                        // Day 317
      ),
      GoRoute(
        path: AppRoutes.regionalPricingMatrix,
        builder: (context, state) =>
            const Day318RegionalPricingMatrixScreen(),                        // Day 318
      ),
      GoRoute(
        path: AppRoutes.gdprConsentWire,
        builder: (context, state) =>
            const Day319GdprConsentWireScreen(),                              // Day 319
      ),
      GoRoute(
        path: AppRoutes.sectionGMilestone,
        builder: (context, state) =>
            const Day320SectionGMilestoneScreen(),                            // Day 320
      ),
      GoRoute(
        path: AppRoutes.sosTriggerRefactor,
        builder: (context, state) =>
            const Day321SosTriggerRefactorScreen(),                           // Day 321
      ),
      GoRoute(
        path: AppRoutes.dcsPipelineWire,
        builder: (context, state) =>
            const Day322DcsPipelineWireScreen(),                              // Day 322
      ),
      GoRoute(
        path: AppRoutes.journeyMlConfidence,
        builder: (context, state) =>
            const Day323JourneyMlConfidenceScreen(),                          // Day 323
      ),
      GoRoute(
        path: AppRoutes.releaseCandidateManifest,
        builder: (context, state) =>
            const Day324ReleaseCandidateManifestScreen(),                     // Day 324
      ),
      GoRoute(
        path: AppRoutes.otaModelUpdate,
        builder: (context, state) =>
            const Day325OtaModelUpdateScreen(),                               // Day 325
      ),
      GoRoute(
        path: AppRoutes.coldStartReport,
        builder: (context, state) =>
            const Day326ColdStartReportScreen(),                             // Day 326
      ),
      GoRoute(
        path: AppRoutes.memoryLeakTracker,
        builder: (context, state) =>
            const Day327MemoryLeakTrackerScreen(),                          // Day 327
      ),
      GoRoute(
        path: AppRoutes.batteryMonitoringProd,
        builder: (context, state) =>
            const Day328BatteryMonitoringProductionScreen(),                // Day 328
      ),
      GoRoute(
        path: AppRoutes.falsePositiveTuningProd,
        builder: (context, state) =>
            const Day329FalsePositiveTuningProductionScreen(),              // Day 329
      ),
      GoRoute(
        path: AppRoutes.sectionHMilestone,
        builder: (context, state) =>
            const Day330SectionHRcMilestoneScreen(),                        // Day 330
      ),
      GoRoute(
        path: AppRoutes.vault,
        builder: (context, state) => const VaultPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        builder: (context, state) => const ContactsPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.day6,
        builder: (context, state) => const Day6AuthFoundationScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissions,
        builder: (context, state) => const Day11PermissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceTier,
        builder: (context, state) => const Day13DeviceTierScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermissions,
        builder: (context, state) => const OnboardingPermissionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.featureFlags,
        builder: (context, state) => const Day14FeatureFlagsScreen(),
      ),
      GoRoute(
        path: AppRoutes.week3Review,
        builder: (context, state) => const Day15Week3ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.pushNotifications,
        builder: (context, state) => const Day16PushNotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.pushRouting,
        builder: (context, state) => const Day17PushRoutingScreen(),
      ),
      GoRoute(
        path: AppRoutes.drillsSchedule,
        builder: (context, state) => const Day18DrillsAndScheduleScreen(),
      ),
      GoRoute(
        path: AppRoutes.month1Integration,
        builder: (context, state) => const Day19Month1IntegrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.month1Review,
        builder: (context, state) => const Day20Month1ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.backgroundEngine,
        builder: (context, state) => const Day21BackgroundServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.watchdog,
        builder: (context, state) => const Day22WatchdogScreen(),
      ),
      GoRoute(
        path: AppRoutes.platformChannels,
        builder: (context, state) => const Day23PlatformChannelsScreen(),
      ),
      GoRoute(
        path: AppRoutes.lp4Watchdog,
        builder: (context, state) => const Day24Lp4WatchdogScreen(),
      ),
      GoRoute(
        path: AppRoutes.week5Review,
        builder: (context, state) => const Day25Week5ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.audioCapture,
        builder: (context, state) => const Day26AudioCaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.audioFeatures,
        builder: (context, state) => const Day27AudioFeaturesScreen(),
      ),
      GoRoute(
        path: AppRoutes.iosAudio,
        builder: (context, state) => const Day28IosAudioScreen(),
      ),
      GoRoute(
        path: AppRoutes.inference,
        builder: (context, state) => const Day29InferenceScreen(),
      ),
      GoRoute(
        path: AppRoutes.week6Review,
        builder: (context, state) => const Day30Week6ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.tfliteModels,
        builder: (context, state) => const Day31TfliteModelsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dcsEngine,
        builder: (context, state) => const Day32DcsEngineScreen(),
      ),
      GoRoute(
        path: AppRoutes.dcsStream,
        builder: (context, state) => const Day33DcsStreamScreen(),
      ),
      GoRoute(
        path: AppRoutes.isolateLatency,
        builder: (context, state) => const Day34IsolateLatencyScreen(),
      ),
      GoRoute(
        path: AppRoutes.week7Review,
        builder: (context, state) => const Day35Week7ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.imuService,
        builder: (context, state) => const Day36ImuServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.gpsService,
        builder: (context, state) => const Day37GpsServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.day38FallbackAndState,
        builder: (context, state) => const Day38FallbackAndStateScreen(),
      ),
      GoRoute(
        path: AppRoutes.day39StateWiring,
        builder: (context, state) => const Day39StateWiringScreen(),
      ),
      GoRoute(
        path: AppRoutes.month2Review,
        builder: (context, state) => const Day40Month2ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep1,
        builder: (context, state) => const Day41OnboardingStep1Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep2,
        builder: (context, state) => const Day42OnboardingStep2Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep3,
        builder: (context, state) => const Day43OnboardingStep3Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep4,
        builder: (context, state) => const Day44OnboardingStep4Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingStep5,
        builder: (context, state) => const Day45OnboardingStep5Screen(),
      ),
      GoRoute(
        path: AppRoutes.heuristicEngine,
        builder: (context, state) => const Day44HeuristicEngineScreen(),
      ),
      GoRoute(
        path: AppRoutes.modelBundle,
        builder: (context, state) => const Day45ModelBundleScreen(),
      ),
      GoRoute(
        path: AppRoutes.detectionSettings,
        builder: (context, state) => const Day46DetectionSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.integrationTests,
        builder: (context, state) => const Day47IntegrationTestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceDiagnostics,
        builder: (context, state) => const Day48DeviceDiagnosticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.audioPipeline,
        builder: (context, state) => const Day49AudioPipelineScreen(),
      ),
      GoRoute(
        path: AppRoutes.motionValidation,
        builder: (context, state) => const Day50MotionValidationScreen(),
      ),
      GoRoute(
        path: AppRoutes.offlineStatus,
        builder: (context, state) => const Day51OfflineStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneCapability,
        builder: (context, state) => const Day52PhoneCapabilityScreen(),
      ),
      GoRoute(
        path: AppRoutes.compatibilityMatrix,
        builder: (context, state) => const Day53CompatibilityMatrixScreen(),
      ),
      GoRoute(
        path: AppRoutes.capabilityReport,
        builder: (context, state) => const Day54CapabilityReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.detectionEvents,
        builder: (context, state) => const Day55DetectionEventScreen(),
      ),
      GoRoute(
        path: AppRoutes.modelDownloads,
        builder: (context, state) => const Day56ModelDownloadScreen(),
      ),
      GoRoute(
        path: AppRoutes.mlAnalytics,
        builder: (context, state) => const Day57MlAnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.safeZones,
        builder: (context, state) => const Day58SafeZoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.protectionScore,
        builder: (context, state) => const Day59ProtectionScoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.drillMode,
        builder: (context, state) => const Day60DrillScreen(),
      ),
      GoRoute(
        path: AppRoutes.inferenceLog,
        builder: (context, state) => const Day61InferenceLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.incidentReport,
        builder: (context, state) => const Day62IncidentScreen(),
      ),
      GoRoute(
        path: AppRoutes.alertThresholds,
        builder: (context, state) => const Day63AlertThresholdScreen(),
      ),
      GoRoute(
        path: AppRoutes.escalationPolicies,
        builder: (context, state) => const Day64EscalationScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkIns,
        builder: (context, state) => const Day65CheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.sosTemplates,
        builder: (context, state) => const Day66SosTemplateScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationPrefs,
        builder: (context, state) => const Day67NotificationPrefScreen(),
      ),
      GoRoute(
        path: AppRoutes.auditLog,
        builder: (context, state) => const Day68AuditLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.dataExport,
        builder: (context, state) => const Day69DataExportScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const Day70PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.alertPending,
        builder: (context, state) => const Day71AlertPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.doNotDisturb,
        builder: (context, state) => const DoNotDisturbScreen(),         // Day 73
      ),
      GoRoute(
        path: AppRoutes.deliveryConfirmation,
        builder: (context, state) => const DeliveryConfirmationScreen(), // Day 75
      ),
      GoRoute(
        path: AppRoutes.notificationHistory,
        builder: (context, state) => const NotificationHistoryScreen(),  // Day 76
      ),
      GoRoute(
        path: AppRoutes.day1,
        builder: (context, state) => const Day1ProjectSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.day9,
        builder: (context, state) => const Day9JwtStorageScreen(),
      ),
      GoRoute(
        path: AppRoutes.day10,
        builder: (context, state) => const Day10AuthReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneEntry,
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (context, state) {
          final args = state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : const <String, dynamic>{};
          return OtpVerifyScreen(
            phone: (args['phone'] as String?) ?? 'your phone',
            expiresIn: (args['expiresIn'] as int?) ?? 120,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Route not found:\n${state.matchedLocation}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  );
});
