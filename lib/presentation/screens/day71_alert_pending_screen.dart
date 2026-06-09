/// Day 71-74 — ALERT_PENDING Screen
///
/// The most security-sensitive screen in ZapSafe.
///
/// LP27 — "Blank-Screen Panic Mode":
///   This screen MUST NOT reveal that an SOS is pending to an attacker.
///   Only a large countdown number and a PIN pad are ever visible in plain
///   sight.  No text says "SOS", "Emergency", "Alert", or "Help".
///
/// ── What was built on Day 71 ──────────────────────────────────────────────
///   • 15-second countdown (ClashDisplay 160 px, per-second fade-in).
///   • Silent haptic pulse every second — attacker cannot hear it.
///   • PIN pad (75×75 WCAG 2.1 AAA touch targets) + 6-dot indicator.
///   • Back-button disabled via PopScope (LP27).
///   • Expiry state: three dots, no text.
///
/// ── Added on Day 72 ───────────────────────────────────────────────────────
///   • DCS explainability card: "Why triggered" block — shown ONLY when the
///     phone is face-up (user is looking at it, attacker cannot see screen).
///   • Proximity detection via accelerometer Z-axis:
///       z > 0  → face-up   → card visible.
///       z ≤ 0  → face-down → card hidden; attacker sees a blank area.
///   • PIN comparison: reads stored PIN from flutter_secure_storage
///     (key: 'zapsafe_cancel_pin').  Falls back to '123456' when no PIN is
///     stored and shows a subtle dev-mode badge for emulator testing.
///   • Wrong PIN: shake animation + heavy haptic + 600 ms red dot flash.
///   • Correct PIN: checkmark state → timer cancelled → auto-pop after 1.5 s.
///
/// ── Added on Day 73 — LP3 Duress PIN ─────────────────────────────────────
///   • Duress PIN (key: 'zapsafe_duress_pin').  Falls back to '999999' in
///     dev/emulator mode when no duress PIN is stored.
///   • Three-way PIN branch:
///       Entered == cancel PIN  → genuine cancel (_onPinCorrect)
///       Entered == duress PIN  → fake cancel    (_onDuressPin)
///       Otherwise              → wrong PIN      (_onPinWrong)
///   • LP3 rule: both genuine cancel and duress cancel show IDENTICAL UI
///     (the same white checkmark, same 1.5 s auto-pop).  An attacker
///     watching over the user's shoulder cannot distinguish them.
///   • _postDuressCancel(): fire-and-forget stub — POST /api/v1/sos/cancel/
///     with {"duress": true}. Wired to real SOS ID on Day 75+.
///   • DEV badge updated: shows both cancel PIN and duress PIN.
///
/// ── Added on Day 74 — LP18 Biometric Confirmation ────────────────────────
///   • After correct cancel PIN, biometric confirmation is requested via
///     local_auth before the SOS is actually stopped.
///   • `_awaitingBiometric` state: disables PIN pad taps while the OS
///     biometric dialog is open and shows a fingerprint icon indicator.
///   • Graceful degradation: if the device has no biometrics
///     (canCheckBiometrics == false && isDeviceSupported == false),
///     the PIN alone is sufficient — no biometric prompt is shown.
///   • Biometric failure (user cancels or finger not recognised): timer
///     resumes, PIN is cleared, user can try again. No shake animation
///     (would look suspicious to an attacker — biometric failure is silent).
///   • Duress PIN path is deliberately EXEMPT from biometric — asking for
///     biometric after a duress PIN would alert the attacker that something
///     unusual is happening. LP3 guarantee preserved.
///   • localizedReason: 'Confirm' — LP27-compliant, no "SOS" or "Emergency".
///
/// ── Week 15 review — Day 75 bug fixes ────────────────────────────────────
///   • PIN snapshot race: `_validatePin` now captures `_pin.join()` BEFORE
///     the `await Future.wait(...)` storage read, so a delete tap during the
///     async window cannot corrupt the comparison value.
///   • Timer-biometric race: `_onPinCorrect` now cancels the countdown timer
///     before opening the OS biometric dialog.  If auth fails the timer is
///     restarted from `_secondsLeft` (preserving remaining time).  Previously
///     the SOS could fire mid-biometric if the user had ≤ dialog-latency
///     seconds left on the clock.
///
/// ── Coming in later days ──────────────────────────────────────────────────
///   • Day 76+: Wire real SOS ID into _postDuressCancel + _onPinCorrect once
///     the active SOS event ID flows from the DCS trigger provider.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const int    _kInitialSeconds    = 15;
const int    _kMaxPinLength      = 6;
const String _kCancelPinKey      = 'zapsafe_cancel_pin';
const String _kDuressPinKey      = 'zapsafe_duress_pin';  // LP3
const String _kFallbackPin       = '123456'; // emulator cancel PIN fallback
const String _kFallbackDuressPin = '999999'; // emulator duress PIN fallback

// ─── DCS trigger data model ───────────────────────────────────────────────────

class _DcsTrigger {
  const _DcsTrigger({
    required this.label,
    required this.confidence,
    required this.contextClues,
  });

  final String       label;        // e.g. "Scream Detected"
  final double       confidence;   // 0.0–1.0
  final List<String> contextClues; // e.g. ["Movement spike", "2:14 AM"]
}

/// Mock data used when the screen is opened from the emulator test index.
/// In production this is populated by the DCS engine state provider.
const _kMockTrigger = _DcsTrigger(
  label:        'Scream Detected',
  confidence:   0.85,
  contextClues: ['Movement spike', '2:14 AM', 'isolated area'],
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day71AlertPendingScreen extends ConsumerStatefulWidget {
  const Day71AlertPendingScreen({super.key});

  @override
  ConsumerState<Day71AlertPendingScreen> createState() =>
      _Day71AlertPendingScreenState();
}

class _Day71AlertPendingScreenState
    extends ConsumerState<Day71AlertPendingScreen>
    with TickerProviderStateMixin {

  // ── Countdown ────────────────────────────────────────────────────────────────
  int    _secondsLeft = _kInitialSeconds;
  bool   _fired       = false;
  Timer? _timer;
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  // ── PIN entry ─────────────────────────────────────────────────────────────────
  final List<int> _pin              = [];
  bool            _pinError         = false;
  bool            _cancelled        = false;
  bool            _testMode         = false;
  /// LP3: true when cancel was triggered by the duress PIN.
  /// The UI is IDENTICAL to a genuine cancel — attacker cannot distinguish.
  bool            _isDuressCancel   = false;
  /// Day 74 — LP18: true while the OS biometric dialog is open.
  /// PIN pad taps are ignored and a fingerprint icon is shown.
  bool            _awaitingBiometric = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  // ── Proximity (Day 72) ────────────────────────────────────────────────────────
  bool                               _faceUp   = true;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  final _storage   = const FlutterSecureStorage();
  // Day 74 — LP18 biometric authentication (local_auth).
  final _localAuth = LocalAuthentication();

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Fade animation — flashes countdown number in on each tick.
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
    _fadeCtrl.value = 1.0; // start fully visible

    // Shake animation — horizontal oscillation on wrong PIN.
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,  end: -9.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9.0, end:  9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  9.0, end: -9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -9.0, end:  9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  9.0, end:  0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _startCountdown();
    _startProximityDetection();
    _checkTestMode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _accelSub?.cancel();
    _fadeCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Countdown ─────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer t) {
    HapticFeedback.mediumImpact(); // silent — attacker cannot hear it
    setState(() {
      _secondsLeft = (_secondsLeft - 1).clamp(0, _kInitialSeconds);
    });
    _fadeCtrl.forward(from: 0.0);

    if (_secondsLeft == 0) {
      t.cancel();
      setState(() {
        _fired = true;
      });
      // Day 75+ wires in: POST /sos/trigger → navigate to SOSActiveScreen.
    }
  }

  // ── Proximity detection (Day 72) ──────────────────────────────────────────────

  void _startProximityDetection() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(
      (event) {
        if (!mounted) {
          return;
        }
        final faceUp = event.z > 0;
        if (faceUp != _faceUp) {
          setState(() {
            _faceUp = faceUp;
          });
        }
      },
      // Sensor unavailable on some emulators — silently keep _faceUp = true.
      onError: (_) {},
    );
  }

  // ── Test mode (Day 72) ────────────────────────────────────────────────────────

  Future<void> _checkTestMode() async {
    final stored = await _storage.read(key: _kCancelPinKey);
    if (mounted && stored == null) {
      setState(() {
        _testMode = true;
      });
    }
  }

  // ── PIN entry ─────────────────────────────────────────────────────────────────

  void _onDigit(int digit) {
    // Day 74: ignore taps while OS biometric dialog is open.
    if (_awaitingBiometric) return;
    if (_pin.length >= _kMaxPinLength) return;
    setState(() {
      _pin.add(digit);
    });
    HapticFeedback.selectionClick();
    if (_pin.length == _kMaxPinLength) {
      _validatePin(); // fire-and-forget — async result handled inside
    }
  }

  void _onDelete() {
    // Day 74: ignore taps while OS biometric dialog is open.
    if (_awaitingBiometric) return;
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _validatePin() async {
    // Day 73 — LP3: three-way branch.
    // Snapshot the PIN BEFORE the storage await.  If the user taps delete
    // during the async read (very unlikely but possible), we still compare
    // the 6-digit value they actually submitted.
    final entered = _pin.join();

    // Read both PINs in parallel for minimum latency.
    final results = await Future.wait([
      _storage.read(key: _kCancelPinKey),
      _storage.read(key: _kDuressPinKey),
    ]);
    final cancelPin = results[0] ?? _kFallbackPin;
    final duressPin = results[1] ?? _kFallbackDuressPin;

    if (entered == cancelPin) {
      await _onPinCorrect();
    } else if (entered == duressPin) {
      await _onDuressPin();
    } else {
      _onPinWrong();
    }
  }

  /// Day 74 — LP18 biometric gate.
  ///
  /// Flow:
  ///   1. Show fingerprint icon (disable PIN pad via _awaitingBiometric).
  ///   2. Request biometric / device-credential auth.
  ///   3. Success → cancel SOS, pop screen (identical UX to genuine cancel).
  ///   4. Failure → silent, timer resumes, PIN cleared, user can retry.
  ///
  /// Duress PIN path (_onDuressPin) bypasses this entirely — asking for
  /// biometric after a duress PIN would alert the attacker.
  Future<void> _onPinCorrect() async {
    // Pause the countdown for the duration of the biometric prompt.
    // Reason: if the user entered the PIN with 2 seconds left and biometric
    // takes 3 seconds, the SOS must NOT fire mid-auth.  The timer is restarted
    // (from wherever _secondsLeft is) only if biometric fails.
    _timer?.cancel();
    setState(() { _awaitingBiometric = true; });

    final authenticated = await _authenticateWithBiometrics();

    if (!mounted) return;

    if (authenticated) {
      await HapticFeedback.heavyImpact();
      setState(() {
        _awaitingBiometric = false;
        _cancelled         = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } else {
      // Biometric failed or cancelled by user.
      // No shake — looks suspicious to attacker if biometric dialog closes
      // and the screen shakes. Just clear the PIN silently, then resume
      // the countdown from wherever _secondsLeft currently is.
      await HapticFeedback.mediumImpact();
      setState(() {
        _awaitingBiometric = false;
        _pin.clear();
      });
      // Resume countdown only if it hasn't already expired.
      if (mounted && !_fired) {
        _startCountdown();
      }
    }
  }

  /// Attempts biometric (or device credential) authentication.
  ///
  /// Returns true if:
  ///   • The device has no biometrics configured → degrade gracefully (PIN alone sufficient).
  ///   • The user successfully authenticates.
  ///
  /// Returns false if:
  ///   • Authentication was cancelled, failed, or threw an exception.
  Future<bool> _authenticateWithBiometrics() async {
    try {
      final canCheck    = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      // Graceful degradation: no biometrics enrolled → treat as success.
      if (!canCheck && !isSupported) return true;
      return await _localAuth.authenticate(
        localizedReason: 'Confirm', // LP27: no "SOS"/"Emergency"
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern as fallback
          stickyAuth:    true,  // persist dialog if user switches apps
        ),
      );
    } catch (_) {
      // PlatformException or any other error → fail gracefully.
      return false;
    }
  }

  // ── Duress PIN handler (Day 73 — LP3) ─────────────────────────────────────

  /// LP3 — Fake-cancel: show identical UI to a genuine cancel while
  /// the SOS continues silently on the backend.
  ///
  /// Critical rule: the UI presented here MUST be visually indistinguishable
  /// from _onPinCorrect() — same checkmark, same haptic, same timing.
  /// An attacker watching over the user's shoulder cannot tell the difference.
  Future<void> _onDuressPin() async {
    _timer?.cancel();
    await HapticFeedback.heavyImpact(); // identical haptic to genuine cancel

    setState(() {
      _isDuressCancel = true; // internal flag only — UI branch below is same
      _cancelled      = true; // renders _CancelledView — same as genuine cancel
    });

    // Fire-and-forget: tell backend this was a duress cancel so it continues
    // the SOS silently.  Does NOT await — cannot block the fake-cancel UX.
    _postDuressCancel();

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.of(context).pop(); // returns to whatever was under the screen
    }
  }

  /// Fire-and-forget stub: POST /api/v1/sos/cancel/ with duress:true.
  ///
  /// Day 75+: replace the debugPrint with a real API call once the active
  /// SOS event ID flows from the DCS trigger provider into this screen:
  ///   await apiClient.post('/api/v1/sos/cancel/', {
  ///     'sos_id': widget.sosId,
  ///     'duress': true,
  ///   });
  ///
  /// The backend receives duress=true and IGNORES the cancel — the SOS
  /// stays active and escalation continues normally.  The user's device
  /// UI shows "cancelled" but contacts are still being notified.
  Future<void> _postDuressCancel() async {
    // Safety assertion: this method must only be called after _isDuressCancel
    // has been set.  Catches any future refactor that accidentally calls this
    // on a genuine cancel path.
    assert(_isDuressCancel, '_postDuressCancel called but _isDuressCancel is false');
    // TODO Day 75: apiClient.post('/api/v1/sos/cancel/', {'duress': true, 'sos_id': sosId});
    debugPrint('[LP3] Duress cancel triggered — SOS continues silently on backend.');
  }

  void _onPinWrong() {
    HapticFeedback.heavyImpact();
    // Flash dots red, then clear after shake completes.
    setState(() {
      _pinError = true;
    });
    _shakeCtrl.forward(from: 0.0);
    Future<void>.delayed(const Duration(milliseconds: 620)).then((_) {
      if (mounted) {
        setState(() {
          _pinError = false;
          _pin.clear();
        });
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_cancelled) {
      body = const _CancelledView();
    } else if (_fired) {
      body = const _FiredView();
    } else {
      body = _PendingView(
        secondsLeft:       _secondsLeft,
        fadeAnim:          _fadeAnim,
        shakeAnim:         _shakeAnim,
        pin:               _pin,
        pinError:          _pinError,
        faceUp:            _faceUp,
        testMode:          _testMode,
        awaitingBiometric: _awaitingBiometric, // Day 74 — LP18
        // Day 73+: replace with ref.watch(dcsTriggerProvider)
        trigger:           _kMockTrigger,
        onDigit:           _onDigit,
        onDelete:          _onDelete,
      );
    }

    return PopScope(
      canPop: false, // LP27: back-button disabled — PIN is the only exit path
      child: Scaffold(
        backgroundColor: ZapColors.bgPrimary,
        body: SafeArea(child: body),
      ),
    );
  }
}

// ─── Pending view ─────────────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  const _PendingView({
    required this.secondsLeft,
    required this.fadeAnim,
    required this.shakeAnim,
    required this.pin,
    required this.pinError,
    required this.faceUp,
    required this.testMode,
    required this.awaitingBiometric, // Day 74 — LP18
    required this.trigger,
    required this.onDigit,
    required this.onDelete,
  });

  final int                secondsLeft;
  final Animation<double>  fadeAnim;
  final Animation<double>  shakeAnim;
  final List<int>          pin;
  final bool               pinError;
  final bool               faceUp;
  final bool               testMode;
  /// Day 74 — true while the OS biometric dialog is open.
  /// Replaces the PIN dot indicator with a fingerprint icon.
  final bool               awaitingBiometric;
  final _DcsTrigger        trigger;
  final ValueChanged<int>  onDigit;
  final VoidCallback       onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Dev-mode badge (emulator only — no stored PIN) ───────────────────
        // Shows both cancel PIN and duress PIN so both paths can be tested.
        // Never visible in production (only when _kCancelPinKey not stored).
        if (testMode)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.only(
                  top: ZapSpacing.sm, right: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: ZapColors.warning.withOpacity(0.4)),
              ),
              child: Text(
                // C = cancel PIN · D = duress PIN (LP3)
                'DEV  C:$_kFallbackPin  D:$_kFallbackDuressPin',
                style: TextStyle(
                  fontSize:   10,
                  color:      ZapColors.warning.withOpacity(0.7),
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            ),
          ),

        // ── Countdown number ─────────────────────────────────────────────────
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: fadeAnim,
                child: Text(
                  '$secondsLeft',
                  style: const TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize:   160,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                    height:     1.0,
                  ),
                ),
              ),

              // ── DCS reason card (Day 72) ────────────────────────────────────
              const SizedBox(height: ZapSpacing.lg),
              _DcsReasonCard(trigger: trigger, visible: faceUp),
            ],
          ),
        ),

        // ── PIN dot indicator / biometric waiting indicator ──────────────────
        // Day 74 — LP18: when biometric dialog is open, swap dots for a
        // fingerprint icon.  LP27: no "Touch ID", "Face ID", or "Scanning"
        // text visible — icon alone is sufficient and ambiguous to an attacker.
        Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.lg),
          child: awaitingBiometric
              ? const SizedBox(
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white54,
                      size:  44,
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: shakeAnim,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(shakeAnim.value, 0),
                    child: child,
                  ),
                  child: _PinDots(filled: pin.length, hasError: pinError),
                ),
        ),

        // ── PIN pad ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZapSpacing.xl, 0, ZapSpacing.xl, ZapSpacing.xxl,
          ),
          child: _PinPad(onDigit: onDigit, onDelete: onDelete),
        ),
      ],
    );
  }
}

// ─── DCS reason card (Day 72) ─────────────────────────────────────────────────

class _DcsReasonCard extends StatelessWidget {
  const _DcsReasonCard({
    required this.trigger,
    required this.visible,
  });

  final _DcsTrigger trigger;
  final bool        visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 280),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve:    Curves.easeInOut,
        child: visible ? _CardBody(trigger: trigger) : const SizedBox.shrink(),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.trigger});

  final _DcsTrigger trigger;

  @override
  Widget build(BuildContext context) {
    final pct = '${(trigger.confidence * 100).round()}%';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.xl),
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      decoration: BoxDecoration(
        color:        ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border:       Border.all(color: ZapColors.bgElevated),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors_rounded,
              color: ZapColors.warning, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trigger.label,
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      ZapColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      pct,
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize:   12,
                        color:      ZapColors.warning.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  trigger.contextClues.join(' · '),
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize:   11,
                    color:      ZapColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cancelled view (correct PIN entered) ─────────────────────────────────────

class _CancelledView extends StatelessWidget {
  const _CancelledView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.check_rounded,
        color: Colors.white,
        size:  72,
      ),
    );
  }
}

// ─── Fired view (SOS dispatched) ──────────────────────────────────────────────

class _FiredView extends StatelessWidget {
  const _FiredView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '• • •',
        style: TextStyle(
          fontSize:      32,
          color:         Colors.white24,
          letterSpacing: 10,
        ),
      ),
    );
  }
}

// ─── PIN dot indicator ────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.hasError});

  final int  filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kMaxPinLength, (i) {
        final isFilled = i < filled;
        Color dotColor;
        if (hasError && isFilled) {
          dotColor = ZapColors.danger.withOpacity(0.85);
        } else if (isFilled) {
          dotColor = Colors.white;
        } else {
          dotColor = Colors.white.withOpacity(0.12);
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
          width:  11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
          ),
        );
      }),
    );
  }
}

// ─── PIN pad ──────────────────────────────────────────────────────────────────

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onDelete});

  final ValueChanged<int> onDigit;
  final VoidCallback      onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinRow(digits: const [1, 2, 3], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.md),
        _PinRow(digits: const [4, 5, 6], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.md),
        _PinRow(digits: const [7, 8, 9], onDigit: onDigit),
        const SizedBox(height: ZapSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(
              width:  ZapSpacing.minTouchTarget,
              height: ZapSpacing.minTouchTarget,
            ),
            _DigitKey(digit: 0, onDigit: onDigit),
            _DeleteKey(onDelete: onDelete),
          ],
        ),
      ],
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({required this.digits, required this.onDigit});

  final List<int>         digits;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _DigitKey(digit: d, onDigit: onDigit))
          .toList(),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onDigit});

  final int               digit;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onDigit(digit),
      child: Container(
        width:  ZapSpacing.minTouchTarget,
        height: ZapSpacing.minTouchTarget,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: const TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize:   26,
            fontWeight: FontWeight.w500,
            color:      Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DeleteKey extends StatelessWidget {
  const _DeleteKey({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDelete,
      child: const SizedBox(
        width:  ZapSpacing.minTouchTarget,
        height: ZapSpacing.minTouchTarget,
        child: Icon(
          Icons.backspace_outlined,
          color: Colors.white38,
          size:  26,
        ),
      ),
    );
  }
}
