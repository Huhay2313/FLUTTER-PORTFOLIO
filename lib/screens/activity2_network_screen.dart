import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity 2 — Network Monitor & Resilient Request Queue
//
// Features:
//   1. Real-time Network Stream Listener (Wi-Fi, Cellular, Offline)
//   2. FIFO Request Queue — Queues requests when multiple are triggered or offline
//   3. Mid-Flight Interruption Recovery — Preserves interrupted requests and re-queues
//   4. Graceful Recovery — Automatically drains queue upon network restoration
//   5. Live Visual Feedback — Progress indicator, queue counter, state badges
// ─────────────────────────────────────────────────────────────────────────────

enum _NetStatus { wifi, cellular, offline }

enum RequestState { queued, running, interrupted, done }

class QueuedRequest {
  final int id;
  final String label;
  final DateTime createdAt;
  RequestState state;
  int currentChunk;
  final int totalChunks;
  String detail;
  int retryCount;

  QueuedRequest({
    required this.id,
    required this.label,
    required this.createdAt,
    this.state = RequestState.queued,
    this.currentChunk = 0,
    this.totalChunks = 10,
    this.detail = 'Waiting in queue',
    this.retryCount = 0,
  });

  double get progress => (currentChunk / totalChunks).clamp(0.0, 1.0);
  int get progressPercent => (progress * 100).toInt();
}

class Activity2NetworkScreen extends StatefulWidget {
  const Activity2NetworkScreen({super.key});

  @override
  State<Activity2NetworkScreen> createState() => _Activity2NetworkScreenState();
}

class _Activity2NetworkScreenState extends State<Activity2NetworkScreen>
    with SingleTickerProviderStateMixin {
  // ── Network State ────────────────────────────────────────────────────────
  _NetStatus _netStatus = _NetStatus.offline;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  DateTime? _lastChangedAt;
  bool _isManualDrop = false;

  // ── Pulse animation for Live status ──────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Request Queue Management ─────────────────────────────────────────────
  final Queue<QueuedRequest> _pendingQueue = Queue<QueuedRequest>();
  final List<QueuedRequest> _allRequests = [];
  QueuedRequest? _activeRequest;
  bool _isQueueWorkerRunning = false;
  int _requestCounter = 1;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Connectivity Setup ───────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    try {
      final initialResults = await Connectivity().checkConnectivity();
      _onConnectivityChanged(initialResults, isInitial: true);
    } catch (_) {
      _onConnectivityChanged([ConnectivityResult.none], isInitial: true);
    }

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) => _onConnectivityChanged(results));
  }

  void _onConnectivityChanged(List<ConnectivityResult> results, {bool isInitial = false}) {
    if (_isManualDrop) return; // Respect manual simulation if active

    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final previous = _netStatus;
    _NetStatus next;

    switch (result) {
      case ConnectivityResult.wifi:
        next = _NetStatus.wifi;
        break;
      case ConnectivityResult.mobile:
        next = _NetStatus.cellular;
        break;
      default:
        next = _NetStatus.offline;
    }

    if (!mounted) return;

    setState(() {
      _netStatus = next;
      _lastChangedAt = DateTime.now();
    });

    if (isInitial) return;

    // Handover or Drop detection
    if (next == _NetStatus.offline && previous != _NetStatus.offline) {
      HapticFeedback.heavyImpact();
      showAppSnackbar(
        context,
        message: 'Connection dropped — active requests will be preserved in queue',
        icon: Icons.wifi_off_rounded,
        isDestructive: true,
      );
    } else if (previous == _NetStatus.offline && next != _NetStatus.offline) {
      HapticFeedback.mediumImpact();
      showAppSnackbar(
        context,
        message: 'Connection restored (${_netStatusName(next)}) — Resuming queue',
        icon: Icons.wifi_rounded,
      );
      // Graceful Recovery: auto-resume the queue
      _drainQueueWorker();
    } else if (previous != next && previous != _NetStatus.offline) {
      HapticFeedback.lightImpact();
      showAppSnackbar(
        context,
        message: 'Handover to ${_netStatusName(next)} — Connection stable',
        icon: Icons.swap_horiz_rounded,
      );
    }
  }

  String _netStatusName(_NetStatus status) {
    switch (status) {
      case _NetStatus.wifi:
        return 'Wi-Fi';
      case _NetStatus.cellular:
        return 'Cellular';
      case _NetStatus.offline:
        return 'Offline';
    }
  }

  // ── Request Trigger & Queuing ────────────────────────────────────────────

  void _triggerRequest() {
    HapticFeedback.lightImpact();
    final id = _requestCounter++;
    final req = QueuedRequest(
      id: id,
      label: 'Request #$id',
      createdAt: DateTime.now(),
      state: RequestState.queued,
      totalChunks: 10,
      currentChunk: 0,
      detail: _netStatus == _NetStatus.offline
          ? 'Queued (Offline — will auto-start when online)'
          : 'Queued (Waiting for slot)',
    );

    setState(() {
      _allRequests.insert(0, req);
      _pendingQueue.add(req);
    });

    showAppSnackbar(
      context,
      message: '${req.label} added to queue (${_pendingQueue.length} pending)',
      icon: Icons.queue_rounded,
    );

    // Try processing if worker is idle
    _drainQueueWorker();
  }

  // ── Queue Processing Worker (FIFO) ───────────────────────────────────────

  Future<void> _drainQueueWorker() async {
    if (_isQueueWorkerRunning) return;
    if (_netStatus == _NetStatus.offline) return;
    if (_pendingQueue.isEmpty) return;

    _isQueueWorkerRunning = true;

    while (_pendingQueue.isNotEmpty && _netStatus != _NetStatus.offline) {
      final req = _pendingQueue.first; // Peek first
      _pendingQueue.removeFirst();     // Pop

      await _executeRequest(req);

      // Small pause between queue items
      if (_netStatus != _NetStatus.offline && _pendingQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (mounted) {
      setState(() {
        _isQueueWorkerRunning = false;
        _activeRequest = null;
      });
    }
  }

  // ── Single Request Execution with Interruption Catching ──────────────────

  Future<void> _executeRequest(QueuedRequest req) async {
    if (_netStatus == _NetStatus.offline) {
      // Re-queue at the front if offline before starting
      _requeueInterrupted(req, 'Connection offline before execution');
      return;
    }

    setState(() {
      _activeRequest = req;
      req.state = RequestState.running;
      req.detail = req.currentChunk > 0
          ? 'Resumed from ${req.progressPercent}% (${req.currentChunk}/${req.totalChunks} chunks)'
          : 'Processing large dataset transfer...';
    });

    try {
      // Stream chunks (simulating continuous transfer of a 5,000-record dataset)
      final startChunk = req.currentChunk;
      for (int i = startChunk + 1; i <= req.totalChunks; i++) {
        // Mid-flight connection check (Interruption or Handover drop)
        if (_netStatus == _NetStatus.offline) {
          throw const SocketException('Connection interrupted during packet transfer');
        }

        // Simulate chunk transfer duration (~350ms per chunk, ~3.5s total)
        await Future.delayed(const Duration(milliseconds: 350));

        if (!mounted) return;

        // Check again after async gap
        if (_netStatus == _NetStatus.offline) {
          throw const SocketException('Connection interrupted during packet transfer');
        }

        setState(() {
          req.currentChunk = i;
          req.detail = 'Streaming data: ${req.progressPercent}% (${i * 500} / 5000 records)';
        });
      }

      // Completed successfully
      if (!mounted) return;
      setState(() {
        req.state = RequestState.done;
        req.currentChunk = req.totalChunks;
        req.detail = 'Completed — 5,000 records loaded';
      });

      HapticFeedback.lightImpact();
    } on SocketException catch (e) {
      _requeueInterrupted(req, e.message);
    } catch (e) {
      _requeueInterrupted(req, 'Network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (_activeRequest == req) {
            _activeRequest = null;
          }
        });
      }
    }
  }

  void _requeueInterrupted(QueuedRequest req, String reason) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    req.retryCount++;
    req.state = RequestState.interrupted;
    req.detail = 'Interrupted at ${req.progressPercent}% — Saved in queue';

    // Put back at the FRONT of the queue so it resumes first!
    if (!_pendingQueue.contains(req)) {
      _pendingQueue.addFirst(req);
    }

    setState(() {
      _activeRequest = null;
    });

    showAppSnackbar(
      context,
      message: '${req.label} interrupted at ${req.progressPercent}% — Preserved in queue',
      icon: Icons.pause_circle_filled_rounded,
      isDestructive: true,
    );
  }

  // ── Manual Simulation Controls (for quick demo in recording) ─────────────

  void _toggleManualDrop() {
    setState(() {
      _isManualDrop = !_isManualDrop;
      if (_isManualDrop) {
        _netStatus = _NetStatus.offline;
        _lastChangedAt = DateTime.now();
      } else {
        // Re-read actual hardware connectivity
        _initConnectivity();
      }
    });

    if (_isManualDrop) {
      showAppSnackbar(
        context,
        message: 'Simulated Network Drop: App is now Offline',
        icon: Icons.wifi_off_rounded,
        isDestructive: true,
      );
    } else {
      showAppSnackbar(
        context,
        message: 'Simulated Network Restored',
        icon: Icons.wifi_rounded,
      );
    }
  }

  // ── Build UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final timeStr = _lastChangedAt == null
        ? '12:00:00'
        : '${_lastChangedAt!.hour.toString().padLeft(2, '0')}:'
            '${_lastChangedAt!.minute.toString().padLeft(2, '0')}:'
            '${_lastChangedAt!.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Activity 2 — Network Monitor',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppPalette.textPrimary(context),
          ),
        ),
        actions: [
          // Quick simulation toggle icon in appbar for presentation
          IconButton(
            tooltip: _isManualDrop ? 'Restore Connection' : 'Simulate Network Drop',
            icon: Icon(
              _isManualDrop ? Icons.wifi_off_rounded : Icons.wifi_tethering_rounded,
              color: _isManualDrop ? AppPalette.accent : AppPalette.primary,
            ),
            onPressed: _toggleManualDrop,
          ),
        ],
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Network Status Card (Wi-Fi / Cellular / Offline) ──────────
          _buildStatusBanner(),
          const SizedBox(height: 14),

          // ── Info Chips: Last Change & Queued Requests ─────────────────
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.access_time_rounded,
                  label: 'Last change',
                  value: timeStr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  icon: Icons.queue_rounded,
                  label: 'Queued',
                  value: '${_pendingQueue.length} request${_pendingQueue.length == 1 ? '' : 's'}',
                  highlight: _pendingQueue.isNotEmpty,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Active Request Progress Banner ────────────────────────────
          if (_activeRequest != null) ...[
            _buildActiveTransferCard(_activeRequest!),
            const SizedBox(height: 16),
          ],

          // ── Request Log Header & List ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REQUEST LOG',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppPalette.textSecondary(context),
                ),
              ),
              if (_pendingQueue.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_pendingQueue.length} WAITING',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_allRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: AppPalette.textSecondary(context).withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No requests yet',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Send Request" below to test queuing and recovery',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppPalette.textSecondary(context).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_allRequests.length, (i) {
              final req = _allRequests[i];
              return FadeSlideEntrance(
                index: i,
                child: _buildRequestTile(req),
              );
            }),

          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
      floatingActionButton: _buildSendRequestFab(),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final (label, icon, color, gradient) = switch (_netStatus) {
      _NetStatus.wifi => (
          'Wi-Fi Connected',
          Icons.wifi_rounded,
          AppPalette.primary,
          AppPalette.brandGradient,
        ),
      _NetStatus.cellular => (
          'Cellular Connected',
          Icons.signal_cellular_alt_rounded,
          const Color(0xFF00796B),
          const LinearGradient(
            colors: [Color(0xFF00796B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      _NetStatus.offline => (
          'Offline',
          Icons.wifi_off_rounded,
          AppPalette.accent,
          LinearGradient(
            colors: [AppPalette.accent, const Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Opacity(
                opacity: _netStatus == _NetStatus.offline ? 1.0 : _pulseAnim.value,
                child: child,
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NETWORK STATUS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _netStatus == _NetStatus.offline ? 'HALTED' : 'LIVE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? AppPalette.accent.withValues(alpha: 0.12)
            : AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: highlight ? AppPalette.accent : AppPalette.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppPalette.accent : AppPalette.primary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTransferCard(QueuedRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${req.label} — In Flight',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
              ),
              Text(
                '${req.progressPercent}%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: req.progress,
              minHeight: 6,
              backgroundColor: AppPalette.primarySoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            req.detail,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppPalette.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(QueuedRequest req) {
    final (icon, color, badgeText) = switch (req.state) {
      RequestState.running => (
          Icons.sync_rounded,
          AppPalette.primary,
          'RUNNING',
        ),
      RequestState.queued => (
          Icons.hourglass_top_rounded,
          const Color(0xFFF57C00), // Amber
          'QUEUED',
        ),
      RequestState.interrupted => (
          Icons.pause_circle_outline_rounded,
          AppPalette.accent,
          'INTERRUPTED',
        ),
      RequestState.done => (
          Icons.check_circle_rounded,
          const Color(0xFF388E3C), // Green
          'DONE',
        ),
    };

    final timeString =
        '${req.createdAt.hour.toString().padLeft(2, '0')}:${req.createdAt.minute.toString().padLeft(2, '0')}:${req.createdAt.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeString — ${req.detail}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppPalette.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendRequestFab() {
    return TapScale(
      onTap: _triggerRequest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF004D40), // Dark Teal matching screenshot
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF004D40).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              'Send Request',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
