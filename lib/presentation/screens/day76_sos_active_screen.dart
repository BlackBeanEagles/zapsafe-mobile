/// Day 76 — SOS_ACTIVE Screen
///
/// Shown immediately after the 15-second ALERT_PENDING countdown expires
/// (or when an automatic SOS trigger fires directly).
///
/// ── LP27 — Blank-Screen Panic Mode ───────────────────────────────────────
///   Attacker sees a near-black (#07070E) screen with an elapsed timer and
///   a PIN pad.  No word says "SOS", "Emergency", "Alert", or "Help".
///   The recording indicator is a single ambiguous dot, never labelled.
///   Back button disabled.
///
/// ── LP15 — Battery Critical Path ─────────────────────────────────────────
///   Battery percentage shown in the top-right corner — the only visually
///   informative element.  Color shifts orange (≤ 20%) and red (≤ 10%) so
///   the user knows recording capacity without anything that reveals context.
///   Thresholds match BATTERY_CAMERA_OFF_PERCENT=20, BATTERY_VAD_ONLY_PERCENT=10
///   from the technical reference.
///
/// ── LP3 — Duress PIN ─────────────────────────────────────────────────────
///   Same guarantee as ALERT_PENDING: duress PIN shows identical "stopped"
///   UI while the backend continues the SOS silently.
///
/// ── LP18 — Biometric gate ────────────────────────────────────────────────
///   Correct cancel PIN → biometric confirmation required before the SOS
///   is actually stopped.  Duress PIN is exempt (same as ALERT_PENDING).
///   Biometric failure: silent (no shake), timer resumes, PIN cleared.
///
/// ── What "minimal UI" means ──────────────────────────────────────────────
///   • Near-black background — preserves battery, hides UI from observer.
///   • Large elapsed timer (ClashDisplay) — user knows how long SOS has been
///     active; no other app-status text is visible.
///   • No audio indicator, no camera-LED overlay, no "recording" label.
///   • Only the battery %, GPS bar, and PIN pad can be seen by an attacker.
///
/// ── Day 79 — GPS Streaming Bar ───────────────────────────────────────────
///   A minimal coordinate bar updates every 10 seconds during SOS_ACTIVE.
///   LP27: no label — just decimal coordinates + "10s" interval marker.
///   Very dim (white12) so it is invisible to a casual observer.
///   Simulated drift until /api/v1/sos/stream-location/ is wired in Month 4.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/constants/app_flags.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../data/models/battery_profile.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/battery_providers.dart';
import '../../domain/providers/gps_providers.dart';
import '../../domain/providers/sos_providers.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const int    _kMaxPinLength      = 6;
const String _kCancelPinKey      = 'zapsafe_cancel_pin';
const String _kDuressPinKey      = 'zapsafe_duress_pin';
const String _kFallbackPin       = '123456';
const String _kFallbackDuressPin = '999999';

// LP15 battery thresholds — match ZAPSAFE_TECHNICAL_REFERENCE.md
const int _kBatteryCameraOff = 20; // orange indicator below this
const int _kBatteryVadOnly   = 10; // red indicator below this

// Day 79 — GPS streaming interval (seconds).
const int _kGpsIntervalSeconds = 10;

// Day 79 — Simulated base coordinates (Delhi, India).
// Real GPS coordinates wired in Month 4 via /api/v1/sos/stream-location/.
const double _kBaseLatitude  = 28.6139;
const double _kBaseLongitude = 77.2090;

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day76SosActiveScreen extends ConsumerStatefulWidget {
  const Day76SosActiveScreen({super.key});

  @override
  ConsumerState<Day76SosActiveScreen> createState() =>
      _Day76SosActiveScreenState();
}

class _Day76SosActiveScreenState
    extends ConsumerState<Day76SosActiveScreen>
    with TickerProviderStateMixin {

  // ── Elapsed timer (counts UP from 0) ─────────────────────────────────────
  int    _elapsedSeconds = 0;
  Timer? _timer;

  // ── Day 79 — GPS streaming (simulated, 10-second intervals) ──────────────
  String _gpsCoords = '${_kBaseLatitude.toStringAsFixed(4)}'
      '  ${_kBaseLongitude.toStringAsFixed(4)}';
  int    _gpsTick   = 0;
  Timer? _gpsTimer;

  // ── Recording dot pulse animation ─────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Shake animation (wrong PIN) ───────────────────────────────────────────
  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shakeAnim;

  // ── PIN entry ──────────────────────────────────────────────────────────────
  final List<int> _pin              = [];
  bool            _pinError         = false;
  bool            _cancelled        = false;
  bool            _testMode         = false;
  /// LP3 — true when the fake-cancel (duress) path was taken.
  bool            _isDuressCancel   = false;
  /// LP18 — true while the OS biometric dialog is open.
  bool            _awaitingBiometric = false;

  final _storage   = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pulsing recording dot — slow, subtle, ~1 Hz.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.25, end: 0.80).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

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

    _startElapsedTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startGpsDisplay();
    });
    _checkTestMode();
  }

  StreamSubscription? _gpsSub;

  @override
  void dispose() {
    _gpsSub?.cancel();
    _timer?.cancel();
    _gpsTimer?.cancel();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startElapsedTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  // ── Day 79 — GPS streaming ────────────────────────────────────────────────

  /// Fires every [_kGpsIntervalSeconds] seconds, shifting the displayed
  /// coordinates by a tiny deterministic drift.  LP27: no label, just numbers.
  /// Replaced with real geolocator stream in Month 4.
  /// Live GPS from [GpsService] when wired; simulated drift in mock mode.
  void _startGpsDisplay() {
    if (kUseMockData) {
      _startSimulatedGpsTimer();
      return;
    }

    _gpsSub = ref.read(gpsServiceProvider).samples.listen((sample) {
      if (!mounted) return;
      setState(() {
        _gpsCoords = '${sample.lat.toStringAsFixed(4)}'
            '  ${sample.lng.toStringAsFixed(4)}';
      });
    });

    final latest = ref.read(gpsServiceProvider).latest;
    if (latest != null && mounted) {
      setState(() {
        _gpsCoords = '${latest.lat.toStringAsFixed(4)}'
            '  ${latest.lng.toStringAsFixed(4)}';
      });
    }
  }

  void _startSimulatedGpsTimer() {
    _gpsTimer = Timer.periodic(
      const Duration(seconds: _kGpsIntervalSeconds),
      (_) {
        if (!mounted) return;
        _gpsTick++;
        // Tiny sine-wave drift on both axes so the coordinate visibly changes
        // without random seed — keeps the UI convincingly alive.
        final lat = _kBaseLatitude  + math.sin(_gpsTick * 0.7) * 0.0008;
        final lng = _kBaseLongitude + math.cos(_gpsTick * 0.5) * 0.0012;
        setState(() {
          _gpsCoords = '${lat.toStringAsFixed(4)}'
              '  ${lng.toStringAsFixed(4)}';
        });
      },
    );
  }

  // ── Test mode ─────────────────────────────────────────────────────────────

  Future<void> _checkTestMode() async {
    final stored = await _storage.read(key: _kCancelPinKey);
    if (mounted && stored == null) setState(() => _testMode = true);
  }

  // ── PIN entry ─────────────────────────────────────────────────────────────

  void _onDigit(int digit) {
    if (_awaitingBiometric) return;
    if (_pin.length >= _kMaxPinLength) return;
    setState(() => _pin.add(digit));
    HapticFeedback.selectionClick();
    if (_pin.length == _kMaxPinLength) _validatePin();
  }

  void _onDelete() {
    if (_awaitingBiometric) return;
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
    HapticFeedback.selectionClick();
  }

  Future<void> _validatePin() async {
    final entered = _pin.join(); // snapshot BEFORE await
    final results = await Future.wait([
      _storage.read(key: _kCancelPinKey),
      _storage.read(key: _kDuressPinKey),
    ]);
    final cancelPin = results[0] ?? _kFallbackPin;
    final duressPin = results[1] ?? _kFallbackDuressPin;

    if (entered == cancelPin) {
      await _onPinCorrect();
    } else if (entered == duressPin) {
      await _onDuressPin(duressPin: duressPin);
    } else {
      _onPinWrong();
    }
  }

  /// LP18 — correct cancel PIN: pause timer, open biometric dialog.
  Future<void> _onPinCorrect() async {
    _timer?.cancel(); // pause countdown during biometric
    setState(() => _awaitingBiometric = true);

    final authenticated = await _authenticateWithBiometrics();
    if (!mounted) return;

    if (authenticated) {
      await HapticFeedback.heavyImpact();
      ref.read(appStateProvider.notifier).onCancelWithRealPIN();
      setState(() { _awaitingBiometric = false; _cancelled = true; });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    } else {
      // Biometric failed — silent (no shake), resume timer.
      await HapticFeedback.mediumImpact();
      setState(() { _awaitingBiometric = false; _pin.clear(); });
      if (mounted && !_cancelled) _startElapsedTimer();
    }
  }

  /// Biometric with graceful degradation (LP18).
  Future<bool> _authenticateWithBiometrics() async {
    try {
      final canCheck    = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) return true; // no biometrics — degrade gracefully
      return await _localAuth.authenticate(
        localizedReason: 'Confirm', // LP27: neutral, no "SOS"
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth:    true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// LP3 — duress PIN: fake cancel, SOS continues silently on backend.
  /// UI is IDENTICAL to genuine cancel (_onPinCorrect success path).
  /// No biometric — asking for biometric after duress would expose the path.
  Future<void> _onDuressPin({required String duressPin}) async {
    _timer?.cancel();
    await HapticFeedback.heavyImpact();
    setState(() { _isDuressCancel = true; _cancelled = true; });
    ref.read(appStateProvider.notifier).onCancelWithDuressPIN();
    _postDuressCancel(duressPin);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  Future<void> _postDuressCancel(String duressPin) async {
    assert(_isDuressCancel, '_postDuressCancel called but _isDuressCancel is false');
    final session = ref.read(activeSosSessionProvider);
    if (session == null || kUseMockData) return;
    unawaited(ref.read(sosServiceProvider).cancel(
          sosId: session.sosId,
          pin: duressPin,
        ));
  }

  void _onPinWrong() {
    HapticFeedback.heavyImpact();
    setState(() => _pinError = true);
    _shakeCtrl.forward(from: 0.0);
    Future<void>.delayed(const Duration(milliseconds: 620)).then((_) {
      if (mounted) setState(() { _pinError = false; _pin.clear(); });
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // LP27: back button disabled
      child: Scaffold(
        // LP27 + battery: darkest possible background to hide UI + conserve battery.
        backgroundColor: ZapColors.bgPrimary,
        body: SafeArea(
          child: _cancelled
              ? const _StoppedView()
              : _ActiveBody(
                  elapsedSeconds:    _elapsedSeconds,
                  pulseAnim:         _pulseAnim,
                  shakeAnim:         _shakeAnim,
                  pin:               _pin,
                  pinError:          _pinError,
                  testMode:          _testMode,
                  awaitingBiometric: _awaitingBiometric,
                  gpsCoords:         _gpsCoords,
                  onDigit:           _onDigit,
                  onDelete:          _onDelete,
                ),
        ),
      ),
    );
  }
}

// ─── Active body ──────────────────────────────────────────────────────────────

class _ActiveBody extends ConsumerWidget {
  const _ActiveBody({
    required this.elapsedSeconds,
    required this.pulseAnim,
    required this.shakeAnim,
    required this.pin,
    required this.pinError,
    required this.testMode,
    required this.awaitingBiometric,
    required this.gpsCoords,
    required this.onDigit,
    required this.onDelete,
  });

  final int                elapsedSeconds;
  final Animation<double>  pulseAnim;
  final Animation<double>  shakeAnim;
  final List<int>          pin;
  final bool               pinError;
  final bool               testMode;
  final bool               awaitingBiometric;
  /// Day 79 — current simulated/real GPS coordinate string.
  final String             gpsCoords;
  final ValueChanged<int>  onDigit;
  final VoidCallback       onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryProfileProvider);

    return Column(
      children: [
        // ── Battery indicator (LP15) + optional dev badge ─────────────────
        Padding(
          padding: const EdgeInsets.only(
            top: ZapSpacing.sm, left: ZapSpacing.sm, right: ZapSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DEV badge (left) — only in test mode (no stored PIN).
              if (testMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: ZapColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
                  ),
                  child: Text(
                    'DEV  C:$_kFallbackPin  D:$_kFallbackDuressPin',
                    style: TextStyle(
                      fontSize:   10,
                      color:      ZapColors.warning.withOpacity(0.7),
                      fontFamily: 'IBMPlexMono',
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              // Battery % (right) — LP15.
              _BatteryLabel(battery: battery),
            ],
          ),
        ),

        // ── Elapsed timer + recording dot ─────────────────────────────────
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatElapsed(elapsedSeconds),
                style: const TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize:   100,
                  fontWeight: FontWeight.w700,
                  color:      Colors.white,
                  height:     1.0,
                ),
              ),

              const SizedBox(height: ZapSpacing.lg),

              // LP27: single dim pulsing dot — ambiguous, never labelled.
              FadeTransition(
                opacity: pulseAnim,
                child: Container(
                  width:  10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Day 79 — GPS streaming bar ────────────────────────────────────
        // LP27: no label — just decimal coordinates + interval.
        // Extremely dim so a glancing observer sees nothing meaningful.
        Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.md),
          child: _GpsStreamBar(coords: gpsCoords),
        ),

        // ── PIN dot indicator / biometric waiting ─────────────────────────
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

        // ── PIN pad ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZapSpacing.xl, 0, ZapSpacing.xl, ZapSpacing.xxl,
          ),
          child: _PinPad(onDigit: onDigit, onDelete: onDelete),
        ),
      ],
    );
  }

  /// Format elapsed seconds as MM:SS (switches to H:MM:SS after 1 hour).
  static String _formatElapsed(int s) {
    final h  = s ~/ 3600;
    final m  = (s % 3600) ~/ 60;
    final ss = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }
}

// ─── Battery label (LP15) ─────────────────────────────────────────────────────

class _BatteryLabel extends StatelessWidget {
  const _BatteryLabel({required this.battery});

  final BatteryProfile battery;

  @override
  Widget build(BuildContext context) {
    if (battery.level < 0) return const SizedBox.shrink(); // unknown level

    final Color color;
    if (battery.level <= _kBatteryVadOnly) {
      color = ZapColors.danger.withOpacity(0.8);
    } else if (battery.level <= _kBatteryCameraOff) {
      color = ZapColors.warning.withOpacity(0.7);
    } else {
      // LP27: keep it very dim above the threshold — not eye-catching.
      color = Colors.white.withOpacity(0.25);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          battery.isCharging
              ? Icons.battery_charging_full_rounded
              : _batteryIcon(battery.level),
          color: color,
          size:  14,
        ),
        const SizedBox(width: 3),
        Text(
          '${battery.level}%',
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize:   11,
            color:      color,
          ),
        ),
      ],
    );
  }

  static IconData _batteryIcon(int level) {
    if (level <= 10) return Icons.battery_0_bar_rounded;
    if (level <= 25) return Icons.battery_1_bar_rounded;
    if (level <= 40) return Icons.battery_2_bar_rounded;
    if (level <= 55) return Icons.battery_3_bar_rounded;
    if (level <= 70) return Icons.battery_4_bar_rounded;
    if (level <= 85) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }
}

// ─── GPS stream bar (Day 79 — LP27 compliant) ─────────────────────────────────
//
// Shows decimal coordinates + "10s" interval.  NO word "GPS", "location", or
// "tracking" — LP27 requires all visible text to be ambiguous to an observer.
// Opacity 0.12 keeps it invisible to a glancing attacker; the user who knows
// to look for it can read the coordinates.

class _GpsStreamBar extends StatelessWidget {
  const _GpsStreamBar({required this.coords});

  final String coords;

  @override
  Widget build(BuildContext context) {
    const dimColor = Colors.white;
    const opacity  = 0.12;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize:      MainAxisSize.min,
      children: [
        // Tiny static dot — same visual language as the pulsing recording dot,
        // but smaller and dimmer.  Ambiguous to observer.
        Container(
          width:  4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dimColor.withOpacity(opacity + 0.04),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$coords  ·  ${_kGpsIntervalSeconds}s',
          style: TextStyle(
            fontFamily:    'IBMPlexMono',
            fontSize:      10,
            color:         dimColor.withOpacity(opacity),
            letterSpacing: 0.4,
            height:        1.0,
          ),
        ),
      ],
    );
  }
}

// ─── Stopped view (after genuine or duress cancel) ───────────────────────────
// LP3: this is visually IDENTICAL for both genuine and duress cancel.

class _StoppedView extends StatelessWidget {
  const _StoppedView();

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
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
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
            const SizedBox(width: ZapSpacing.minTouchTarget, height: ZapSpacing.minTouchTarget),
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
      children: digits.map((d) => _DigitKey(digit: d, onDigit: onDigit)).toList(),
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
        child: Icon(Icons.backspace_outlined, color: Colors.white38, size: 26),
      ),
    );
  }
}
