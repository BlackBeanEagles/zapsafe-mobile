//
//  AudioCaptureEngine.swift
//  Runner
//
//  Day 28 — iOS counterpart to Android's AudioCaptureService.kt.
//
//  Uses AVAudioEngine + an input-tap on the device microphone. The hardware
//  format is usually 44.1 / 48 kHz mono float32; we resample to 16 kHz mono
//  int16 via AVAudioConverter to match the Day 26 Android pipeline byte-
//  for-byte. Same 450 ms sliding window, same RMS VAD threshold, same Hann
//  taper — so the Flutter side never has to special-case iOS.
//
//  Features (MFCC + ZCR + centroid) are NOT yet computed here. The Swift
//  port of MfccExtractor lands on Day 29; until then iOS subscribers will
//  see frames over `com.zapsafe/audio.events` but no events on
//  `com.zapsafe/audio.features`. The Dart side already handles that case.
//

import AVFoundation
import Flutter
import Foundation

@objc public class AudioCaptureEngine: NSObject {

    // ─── Channel + format constants (mirrored on Android side) ─────────────
    public static let CHANNEL_NAME        = "com.zapsafe/audio"
    public static let FRAMES_CHANNEL_NAME = "com.zapsafe/audio.events"
    public static let FEATURES_CHANNEL_NAME = "com.zapsafe/audio.features"

    public static let SAMPLE_RATE_HZ: Double = 16000
    public static let WINDOW_MS: Int = 450
    public static let WINDOW_SAMPLES: Int = Int(SAMPLE_RATE_HZ) * WINDOW_MS / 1000  // 7 200
    public static let VAD_RMS_THRESHOLD: Double = 300.0

    // ─── Engine state ──────────────────────────────────────────────────────
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    /// 16 kHz int16 ring buffer — frames are emitted each time it fills.
    private var slidingBuffer: [Int16] = []
    private let hannWindow: [Double]

    private var frameSink: FlutterEventSink?
    @objc public private(set) var isRunning: Bool = false

    /// Singleton — created from AppDelegate during launch.
    @objc public static let shared = AudioCaptureEngine()

    private override init() {
        // Pre-compute the Hann window. Same coefficients as Android.
        let n = AudioCaptureEngine.WINDOW_SAMPLES
        var w = [Double](repeating: 0, count: n)
        for i in 0..<n {
            w[i] = 0.5 * (1.0 - cos(2.0 * .pi * Double(i) / Double(n - 1)))
        }
        self.hannWindow = w
        super.init()
        // Allocate the sliding buffer once with capacity so we don't re-alloc
        // on every frame.
        self.slidingBuffer.reserveCapacity(n)
    }

    // ─── Public registration ───────────────────────────────────────────────

    @objc public static func register(with messenger: FlutterBinaryMessenger) {
        let i = AudioCaptureEngine.shared

        let methodChannel = FlutterMethodChannel(
            name: CHANNEL_NAME, binaryMessenger: messenger)
        methodChannel.setMethodCallHandler { call, result in
            switch call.method {
            case "start":        result(i.start())
            case "stop":         i.stop();  result(true)
            case "isRecording":  result(i.isRunning)
            case "vadThreshold": result(VAD_RMS_THRESHOLD)
            case "sampleRateHz": result(Int(SAMPLE_RATE_HZ))
            case "windowMs":     result(WINDOW_MS)
            // Day 27 features not yet ported to iOS — return 0 so the
            // Flutter spec card shows "—" rather than misleading values.
            case "mfccCount":    result(0)
            case "melBins":      result(0)
            case "fftSize":      result(0)
            default:             result(FlutterMethodNotImplemented)
            }
        }

        FlutterEventChannel(name: FRAMES_CHANNEL_NAME, binaryMessenger: messenger)
            .setStreamHandler(AudioStreamHandler(
                onListen: { i.frameSink = $0 },
                onCancel: { i.frameSink = nil }
            ))

        // Features channel is registered with a no-op handler so the Dart
        // side's listen attempts don't error. When the Swift MFCC extractor
        // ships on Day 29 it'll plug into this slot.
        FlutterEventChannel(name: FEATURES_CHANNEL_NAME, binaryMessenger: messenger)
            .setStreamHandler(AudioStreamHandler(
                onListen: { _ in },
                onCancel: {}
            ))
    }

    // ─── Lifecycle ─────────────────────────────────────────────────────────

    private func start() -> Bool {
        if isRunning { return true }

        // 1. Audio session — record category at measurement mode (no gain
        //    boost, low-latency). Must succeed before the engine starts.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record,
                                    mode: .measurement,
                                    options: [.allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            NSLog("[zapsafe/audio-ios] session setup failed: \(error)")
            return false
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // 2. Target format — 16 kHz mono int16, matching Android pipeline.
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Self.SAMPLE_RATE_HZ,
            channels: 1,
            interleaved: true
        ) else {
            NSLog("[zapsafe/audio-ios] target format unavailable")
            return false
        }
        targetFormat = target

        // 3. Converter — handles any sample rate / channel count from the
        //    hardware (typically 44.1 or 48 kHz float32) down to our target.
        converter = AVAudioConverter(from: inputFormat, to: target)
        if converter == nil {
            NSLog("[zapsafe/audio-ios] converter unavailable")
            return false
        }

        // 4. Install tap with a buffer big enough that AVAudioConverter has
        //    something useful to work with each call (~1024 source samples).
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: inputFormat) { [weak self] (buffer, _) in
            self?.handleSourceBuffer(buffer)
        }

        do {
            try engine.start()
            isRunning = true
            slidingBuffer.removeAll(keepingCapacity: true)
            NSLog("[zapsafe/audio-ios] capture started")
            return true
        } catch {
            NSLog("[zapsafe/audio-ios] engine.start failed: \(error)")
            return false
        }
    }

    private func stop() {
        if !isRunning { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        slidingBuffer.removeAll(keepingCapacity: true)
        NSLog("[zapsafe/audio-ios] capture stopped")
    }

    // ─── Audio plumbing ────────────────────────────────────────────────────

    private func handleSourceBuffer(_ source: AVAudioPCMBuffer) {
        guard let converter = converter, let target = targetFormat else { return }

        // Compute an output capacity that comfortably holds whatever the
        // converter produces. Ratio is target_sr / source_sr; we round up
        // and pad an extra frame to avoid running out mid-decode.
        let ratio = target.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(
            pcmFormat: target,
            frameCapacity: capacity
        ) else { return }

        var consumed = false
        let status = converter.convert(to: out, error: nil) { _, outStatus in
            // Vend the source buffer exactly once per call.
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return source
        }
        if status == .error { return }

        guard let raw = out.int16ChannelData else { return }
        let frames = Int(out.frameLength)
        if frames <= 0 { return }
        let channel = raw[0]

        // Append converted samples into the sliding buffer and emit a frame
        // every time we have >= one window's worth.
        for i in 0..<frames {
            slidingBuffer.append(channel[i])
            if slidingBuffer.count >= Self.WINDOW_SAMPLES {
                emitFrame()
                // Slide forward by a full window — no overlap. Matches Android.
                slidingBuffer.removeFirst(Self.WINDOW_SAMPLES)
            }
        }
    }

    private func emitFrame() {
        let samples = slidingBuffer.prefix(Self.WINDOW_SAMPLES)
        let n = samples.count

        // RMS energy
        var sumSquares: Double = 0
        for s in samples {
            let v = Double(s)
            sumSquares += v * v
        }
        let rms = n > 0 ? sqrt(sumSquares / Double(n)) : 0
        let voiced = rms > Self.VAD_RMS_THRESHOLD

        // Hann window applied in-place on the prefix copy (no FFT yet).
        if voiced {
            var arr = Array(samples)
            for i in 0..<n {
                let windowed = Double(arr[i]) * hannWindow[i]
                arr[i] = Int16(max(Double(Int16.min),
                                   min(Double(Int16.max), windowed)))
            }
            // `arr` discarded — Day 29 will hand it to the FFT/MFCC pipeline.
        }

        let payload: [String: Any] = [
            "t":      Int(Date().timeIntervalSince1970 * 1000),
            "rms":    rms,
            "voiced": voiced,
            "n":      n,
            "window": Self.WINDOW_MS,
            "thr":    Self.VAD_RMS_THRESHOLD,
        ]

        // EventSink calls must happen on the main thread.
        DispatchQueue.main.async { [weak self] in
            self?.frameSink?(payload)
        }
    }
}

// MARK: - Tiny stream-handler shim

private final class AudioStreamHandler: NSObject, FlutterStreamHandler {
    private let onListenCallback: (FlutterEventSink) -> Void
    private let onCancelCallback: () -> Void

    init(onListen: @escaping (FlutterEventSink) -> Void,
         onCancel: @escaping () -> Void) {
        self.onListenCallback = onListen
        self.onCancelCallback = onCancel
    }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListenCallback(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancelCallback()
        return nil
    }
}
