import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// NetworkTier — connection health tier enum
// Excellent : download > 10 Mbps AND ping < 50 ms
// Fair      : download 2–10 Mbps  OR  ping 50–150 ms
// Poor      : download < 2 Mbps   OR  ping 150–400 ms
// Degraded  : ping > 400 ms / socket errors / packet loss
// ─────────────────────────────────────────────────────────────────────────────
enum NetworkTier { excellent, fair, poor, degraded }

// Describes one completed diagnostic cycle.
class DiagnosticSnapshot {
  final DateTime timestamp;
  final int idlePingMs;
  final double downloadMbps;
  final int downloadPingMs; // ping during download phase
  final double uploadMbps;
  final int uploadPingMs; // ping during upload phase
  final NetworkTier tier;
  final String tierLabel;

  const DiagnosticSnapshot({
    required this.timestamp,
    required this.idlePingMs,
    required this.downloadMbps,
    required this.downloadPingMs,
    required this.uploadMbps,
    required this.uploadPingMs,
    required this.tier,
    required this.tierLabel,
  });
}

// Three diagnostic phases — drives the stepper animation in the UI.
enum DiagnosticPhase { idle, phase1Ping, phase2Download, phase3Upload, done }

// ─────────────────────────────────────────────────────────────────────────────
// NetworkHealthProvider — ChangeNotifier (global state injected via Provider)
//
// Exposes:
//   • currentTier / latestSnapshot       — what the adaptive UI reads
//   • isDiagnosticRunning / currentPhase — drive the stepper UI
//   • history                            — last 10 snapshots
//   • runDiagnostic()                    — trigger manually
//
// Auto-repeats every 30 seconds via a Timer.periodic started in constructor.
// ─────────────────────────────────────────────────────────────────────────────
class NetworkHealthProvider extends ChangeNotifier {
  // ── Current Health State (broadcasted globally) ──────────────────────────
  NetworkTier _currentTier = NetworkTier.degraded;
  DiagnosticSnapshot? _latestSnapshot;
  bool _isDiagnosticRunning = false;
  DiagnosticPhase _currentPhase = DiagnosticPhase.idle;
  String _statusMessage = 'Tap "Run Diagnostic" or wait for auto-scan';

  // ── History (last 10 runs) ───────────────────────────────────────────────
  final List<DiagnosticSnapshot> _history = [];

  // ── Background timer ─────────────────────────────────────────────────────
  Timer? _autoTimer;

  // Publicly accessible getters
  NetworkTier get currentTier => _currentTier;
  DiagnosticSnapshot? get latestSnapshot => _latestSnapshot;
  bool get isDiagnosticRunning => _isDiagnosticRunning;
  DiagnosticPhase get currentPhase => _currentPhase;
  String get statusMessage => _statusMessage;
  List<DiagnosticSnapshot> get history => List.unmodifiable(_history);

  NetworkHealthProvider() {
    // Auto-run an initial scan on startup, then every 30 seconds.
    Future.delayed(const Duration(seconds: 2), runDiagnostic);
    _autoTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => runDiagnostic(),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> runDiagnostic() async {
    if (_isDiagnosticRunning) return;

    _isDiagnosticRunning = true;
    _currentPhase = DiagnosticPhase.idle;
    _statusMessage = 'Starting diagnostic...';
    notifyListeners();

    try {
      // ── Phase 1: Baseline Idle Ping ─────────────────────────────────────
      _currentPhase = DiagnosticPhase.phase1Ping;
      _statusMessage = 'Phase 1: Measuring baseline idle ping...';
      notifyListeners();

      final idlePingMs = await _measureIdlePing();

      // ── Phase 2: Download Bandwidth + Concurrent Ping ───────────────────
      _currentPhase = DiagnosticPhase.phase2Download;
      _statusMessage = 'Phase 2: Measuring download speed & concurrent ping...';
      notifyListeners();

      final (downloadMbps, downloadPingMs) = await _measureDownloadWithPing();

      // ── Phase 3: Upload Bandwidth + Concurrent Upload Ping ──────────────
      _currentPhase = DiagnosticPhase.phase3Upload;
      _statusMessage = 'Phase 3: Measuring upload speed & concurrent ping...';
      notifyListeners();

      final (uploadMbps, uploadPingMs) = await _measureUploadWithPing();

      // ── Threshold Analysis ──────────────────────────────────────────────
      final tier = _classifyTier(
        idlePingMs: idlePingMs,
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
        avgPingMs: ((downloadPingMs + uploadPingMs) / 2).round(),
      );

      final snapshot = DiagnosticSnapshot(
        timestamp: DateTime.now(),
        idlePingMs: idlePingMs,
        downloadMbps: downloadMbps,
        downloadPingMs: downloadPingMs,
        uploadMbps: uploadMbps,
        uploadPingMs: uploadPingMs,
        tier: tier,
        tierLabel: _tierLabel(tier),
      );

      _latestSnapshot = snapshot;
      _currentTier = tier;
      _history.insert(0, snapshot);
      if (_history.length > 10) _history.removeLast();

      _currentPhase = DiagnosticPhase.done;
      _statusMessage =
          'Last scan: ${_fmt(snapshot.timestamp)} — ${snapshot.tierLabel}';
    } catch (e) {
      // Any unhandled error → Degraded tier
      _currentTier = NetworkTier.degraded;
      _currentPhase = DiagnosticPhase.done;
      _statusMessage = 'Diagnostic failed: ${e.toString().split('\n').first}';
    } finally {
      _isDiagnosticRunning = false;
      notifyListeners();
    }
  }

  // ── Phase 1: Idle Ping via TCP socket to 1.1.1.1:80 ─────────────────────
  // Opens a raw TCP connection to Cloudflare's DNS resolver (port 80),
  // measures the round-trip, closes it. Repeated 5× and averaged.
  Future<int> _measureIdlePing({int samples = 5}) async {
    final List<int> rtts = [];

    for (int i = 0; i < samples; i++) {
      try {
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          '1.1.1.1',
          80,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        socket.destroy();
        rtts.add(stopwatch.elapsedMilliseconds);
      } catch (_) {
        rtts.add(999); // packet loss / unreachable → high latency
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (rtts.isEmpty) return 999;
    final avg = rtts.reduce((a, b) => a + b) ~/ rtts.length;
    return avg;
  }

  // ── Phase 2: Download bandwidth + concurrent ping ────────────────────────
  // Downloads a ~3.8 MB test binary from Cloudflare's speed test endpoint
  // while concurrently firing 5 pings.
  Future<(double downloadMbps, int downloadPingMs)> _measureDownloadWithPing() async {
    double downloadMbps = 0.0;
    int pingMs = 0;

    final results = await Future.wait([
      _downloadBandwidth(),
      _measureIdlePing(samples: 5),
    ]);

    downloadMbps = results[0] as double;
    pingMs = results[1] as int;

    return (downloadMbps, pingMs);
  }

  Future<double> _downloadBandwidth() async {
    try {
      // Cloudflare speed test: 10MB test file (will be interrupted after 5s)
      // Falls back to a smaller file if it fails.
      const testUrl =
          'https://speed.cloudflare.com/__down?bytes=5000000'; // 5 MB

      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw TimeoutException('Download timed out'),
      );
      stopwatch.stop();

      if (response.statusCode != 200) return 0.0;

      final bytes = response.bodyBytes.length;
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) return 0.0;

      // Convert bytes to Megabits per second: (bytes * 8) / (seconds * 1,000,000)
      final mbps = (bytes * 8) / (seconds * 1000000);
      return double.parse(mbps.toStringAsFixed(2));
    } catch (_) {
      return 0.0;
    }
  }

  // ── Phase 3: Upload bandwidth + concurrent upload ping ───────────────────
  // Generates a 512 KB payload and POSTs it to httpbin.org/post while
  // concurrently pinging to measure upload-phase latency.
  Future<(double uploadMbps, int uploadPingMs)> _measureUploadWithPing() async {
    double uploadMbps = 0.0;
    int pingMs = 0;

    final results = await Future.wait([
      _uploadBandwidth(),
      _measureIdlePing(samples: 5),
    ]);

    uploadMbps = results[0] as double;
    pingMs = results[1] as int;

    return (uploadMbps, pingMs);
  }

  Future<double> _uploadBandwidth() async {
    try {
      // Generate a 512 KB random byte payload
      const uploadBytes = 512 * 1024; // 512 KB
      final payload = Uint8List.fromList(
        List<int>.generate(uploadBytes, (i) => Random().nextInt(256)),
      );

      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            Uri.parse('https://httpbin.org/post'),
            headers: {'Content-Type': 'application/octet-stream'},
            body: payload,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Upload timed out'),
          );
      stopwatch.stop();

      if (response.statusCode != 200) return 0.0;

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) return 0.0;

      final mbps = (uploadBytes * 8) / (seconds * 1000000);
      return double.parse(mbps.toStringAsFixed(2));
    } catch (_) {
      return 0.0;
    }
  }

  // ── Threshold Logic — Classify tier from results ─────────────────────────
  NetworkTier _classifyTier({
    required int idlePingMs,
    required double downloadMbps,
    required double uploadMbps,
    required int avgPingMs,
  }) {
    // Degraded: heavy packet loss (ping > 400ms or no download at all)
    if (idlePingMs >= 400 || avgPingMs >= 400 || downloadMbps == 0.0) {
      return NetworkTier.degraded;
    }

    // Excellent: download > 10 Mbps AND ping < 50 ms
    if (downloadMbps > 10.0 && idlePingMs < 50) {
      return NetworkTier.excellent;
    }

    // Fair: download 2–10 Mbps OR ping 50–150 ms
    if (downloadMbps >= 2.0 && idlePingMs < 150) {
      return NetworkTier.fair;
    }
    if (idlePingMs >= 50 && idlePingMs < 150) {
      return NetworkTier.fair;
    }

    // Poor: download < 2 Mbps OR ping 150–400 ms
    return NetworkTier.poor;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _tierLabel(NetworkTier tier) {
    switch (tier) {
      case NetworkTier.excellent:
        return 'Excellent';
      case NetworkTier.fair:
        return 'Fair';
      case NetworkTier.poor:
        return 'Poor';
      case NetworkTier.degraded:
        return 'Degraded';
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
