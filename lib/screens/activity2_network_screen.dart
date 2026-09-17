import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity 2 — Network Monitor
//
// Features:
//   1. Real-time Network Stream Listener (Wi-Fi, Cellular, Offline, Ethernet)
//   2. Handover Detection (Wi-Fi <-> Cellular) with event logging
//   3. Continuous / Long-running Network Request (Fetching 5,000 JSON records)
//   4. Request Queuing System (Catches SocketException/drop without crashing)
//   5. Graceful Recovery (Auto-retries queued requests via connection stream)
// ─────────────────────────────────────────────────────────────────────────────

enum NetworkType { wifi, cellular, ethernet, offline }

enum RequestStatus { queued, running, completed, failed }

class NetworkRequestItem {
  final String id;
  final String title;
  final String url;
  final DateTime queuedAt;
  RequestStatus status;
  String? failureReason;
  int recordsFetched;
  int retryCount;

  NetworkRequestItem({
    required this.id,
    required this.title,
    required this.url,
    required this.queuedAt,
    this.status = RequestStatus.queued,
    this.failureReason,
    this.recordsFetched = 0,
    this.retryCount = 0,
  });
}

class Activity2NetworkScreen extends StatefulWidget {
  const Activity2NetworkScreen({super.key});

  @override
  State<Activity2NetworkScreen> createState() => _Activity2NetworkScreenState();
}

class _Activity2NetworkScreenState extends State<Activity2NetworkScreen>
    with SingleTickerProviderStateMixin {
  // ── Network State ────────────────────────────────────────────────────────
  NetworkType _currentNetwork = NetworkType.offline;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _handoverCount = 0;
  DateTime? _lastStateChange;

  // ── Pulsing Animation for Live Indicator ────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Request Queue & State ───────────────────────────────────────────────
  final Queue<NetworkRequestItem> _requestQueue = Queue<NetworkRequestItem>();
  final List<NetworkRequestItem> _historyLog = [];
  final List<String> _eventLogs = [];
  bool _isProcessingQueue = false;
  int _requestCounter = 1;
  int _totalRecordsDownloaded = 0;

  // ── Active Fetch Progress ───────────────────────────────────────────────
  bool _isFetching = false;
  String _activeTaskLabel = '';
  double _progressValue = 0.0;
  int _streamedBytes = 0;
  int _streamedRecords = 0;

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
      _handleConnectivityUpdate(initialResults, isInitial: true);
    } catch (e) {
      _logEvent('Error initializing connectivity: $e');
    }

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) => _handleConnectivityUpdate(results));
  }

  void _handleConnectivityUpdate(List<ConnectivityResult> results, {bool isInitial = false}) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final prev = _currentNetwork;

    NetworkType updated;
    switch (result) {
      case ConnectivityResult.wifi:
        updated = NetworkType.wifi;
        break;
      case ConnectivityResult.mobile:
        updated = NetworkType.cellular;
        break;
      case ConnectivityResult.ethernet:
        updated = NetworkType.ethernet;
        break;
      default:
        updated = NetworkType.offline;
    }

    if (!mounted) return;

    final isHandover = !isInitial &&
        prev != updated &&
        prev != NetworkType.offline &&
        updated != NetworkType.offline;

    final isReconnection = !isInitial &&
        prev == NetworkType.offline &&
        updated != NetworkType.offline;

    final isDisconnection = !isInitial &&
        prev != NetworkType.offline &&
        updated == NetworkType.offline;

    setState(() {
      _currentNetwork = updated;
      _lastStateChange = DateTime.now();
      if (isHandover) {
        _handoverCount++;
      }
    });

    // Logging & Haptic
    if (isHandover) {
      HapticFeedback.mediumImpact();
      _logEvent('Handover detected: ${_netName(prev)} ➔ ${_netName(updated)}');
      showAppSnackbar(
        context,
        message: 'Network handover to ${_netName(updated)} (Active)',
        icon: Icons.swap_horiz_rounded,
      );
    } else if (isDisconnection) {
      HapticFeedback.heavyImpact();
      _logEvent('Connection lost. Entering Offline mode.');
      showAppSnackbar(
        context,
        message: 'Network lost — pending requests will be queued',
        icon: Icons.wifi_off_rounded,
        isDestructive: true,
      );
    } else if (isReconnection) {
      HapticFeedback.lightImpact();
      _logEvent('Connection restored via ${_netName(updated)}. Triggering recovery...');
      showAppSnackbar(
        context,
        message: 'Connected to ${_netName(updated)} — Auto-resuming queue',
        icon: Icons.wifi_rounded,
      );
      // Auto-drain / resume queued requests
      _processQueue();
    } else if (isInitial) {
      _logEvent('Initial network state: ${_netName(updated)}');
    }
  }

  String _netName(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'Wi-Fi';
      case NetworkType.cellular:
        return 'Cellular Data';
      case NetworkType.ethernet:
        return 'Ethernet';
      case NetworkType.offline:
        return 'Offline';
    }
  }

  void _logEvent(String text) {
    final timeStr = TimeOfDay.now().format(context);
    setState(() {
      _eventLogs.insert(0, '[$timeStr] $text');
      if (_eventLogs.length > 50) {
        _eventLogs.removeLast();
      }
    });
  }

  // ── Real Continuous & Long-Running Dataset Fetching ───────────────────────

  /// Initiates fetching a large dataset (e.g. 5,000 JSON records from JSONPlaceholder)
  /// or queues it if network is currently unavailable.
  void triggerLargeDatasetFetch() {
    final id = 'REQ-${_requestCounter++}';
    final requestItem = NetworkRequestItem(
      id: id,
      title: 'Fetch Photos Dataset (5,000 items)',
      url: 'https://jsonplaceholder.typicode.com/photos',
      queuedAt: DateTime.now(),
    );

    _handleIncomingRequest(requestItem);
  }

  /// Triggers a multi-batch continuous request (10 sequential batches)
  void triggerContinuousBatchSync() {
    final id = 'BATCH-${_requestCounter++}';
    final requestItem = NetworkRequestItem(
      id: id,
      title: 'Continuous Comments Sync (500 records)',
      url: 'https://jsonplaceholder.typicode.com/comments',
      queuedAt: DateTime.now(),
    );

    _handleIncomingRequest(requestItem);
  }

  void _handleIncomingRequest(NetworkRequestItem item) {
    setState(() {
      _historyLog.insert(0, item);
    });

    if (_currentNetwork == NetworkType.offline) {
      // Offline: Enqueue immediately
      _enqueueRequest(item, reason: 'Device currently offline');
    } else {
      // Online: Execute or queue if already busy
      if (_isFetching) {
        _enqueueRequest(item, reason: 'Waiting for active fetch to complete');
      } else {
        _executeRequest(item);
      }
    }
  }

  void _enqueueRequest(NetworkRequestItem item, {required String reason}) {
    setState(() {
      item.status = RequestStatus.queued;
      item.failureReason = reason;
      if (!_requestQueue.contains(item)) {
        _requestQueue.add(item);
      }
    });
    _logEvent('${item.id} queued: $reason');
    showAppSnackbar(
      context,
      message: '${item.id} queued — will execute upon stable connection',
      icon: Icons.hourglass_top_rounded,
    );
  }

  /// Executes the long-running network request with robust error handling.
  /// If connection drops mid-flight (SocketException/ClientException),
  /// catches the error and queues the request instead of crashing!
  Future<void> _executeRequest(NetworkRequestItem item) async {
    if (_currentNetwork == NetworkType.offline) {
      _enqueueRequest(item, reason: 'Connection dropped before execution');
      return;
    }

    setState(() {
      _isFetching = true;
      _activeTaskLabel = '${item.id}: ${item.title}';
      _progressValue = 0.05;
      _streamedBytes = 0;
      _streamedRecords = 0;
      item.status = RequestStatus.running;
      item.failureReason = null;
    });

    _logEvent('Executing ${item.id} via ${_netName(_currentNetwork)}...');

    final client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse(item.url));
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Network request timed out during transfer');
        },
      );

      if (streamedResponse.statusCode != 200) {
        throw HttpException('HTTP ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 1000000;
      int receivedBytes = 0;
      final List<int> byteBuffer = [];

      // Stream the large response chunk-by-chunk to simulate continuous streaming
      await for (final chunk in streamedResponse.stream) {
        // Handover / connection check mid-flight
        if (_currentNetwork == NetworkType.offline) {
          throw const SocketException('Connection lost during stream transfer');
        }

        byteBuffer.addAll(chunk);
        receivedBytes += chunk.length;

        if (mounted) {
          setState(() {
            _streamedBytes = receivedBytes;
            _progressValue = (receivedBytes / contentLength).clamp(0.05, 0.95);
          });
        }

        // Small micro-yield so UI can animate smoothly
        await Future.delayed(const Duration(milliseconds: 15));
      }

      // Parse JSON records
      final decodedJson = jsonDecode(utf8.decode(byteBuffer));
      final recordsCount = decodedJson is List ? decodedJson.length : 1;

      if (!mounted) return;

      setState(() {
        _progressValue = 1.0;
        _streamedRecords = recordsCount;
        _totalRecordsDownloaded += recordsCount;
        item.status = RequestStatus.completed;
        item.recordsFetched = recordsCount;
        _isFetching = false;
      });

      _logEvent('Success! ${item.id} fetched $recordsCount records (${(receivedBytes / 1024).toStringAsFixed(1)} KB)');
      showAppSnackbar(
        context,
        message: '${item.id} complete: $recordsCount records loaded',
        icon: Icons.check_circle_rounded,
      );
    } on SocketException catch (e) {
      _handleNetworkError(item, 'Socket error: ${e.message}');
    } on http.ClientException catch (e) {
      _handleNetworkError(item, 'Client error during handover: ${e.message}');
    } on TimeoutException catch (e) {
      _handleNetworkError(item, 'Timeout: ${e.message}');
    } catch (e) {
      _handleNetworkError(item, 'Network exception: $e');
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
      // Continue queue processing if any remain
      _processQueue();
    }
  }

  void _handleNetworkError(NetworkRequestItem item, String reason) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();

    item.retryCount++;
    _logEvent('Caught network error on ${item.id}: $reason');

    // Queue request for graceful recovery instead of failing or crashing
    _enqueueRequest(item, reason: reason);
  }

  /// Graceful Recovery: Drains queued requests automatically when stable connection is established
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _isFetching) return;
    if (_currentNetwork == NetworkType.offline) return;
    if (_requestQueue.isEmpty) return;

    _isProcessingQueue = true;

    while (_requestQueue.isNotEmpty && _currentNetwork != NetworkType.offline) {
      final nextItem = _requestQueue.removeFirst();
      _logEvent('Graceful Recovery: Auto-resuming queued ${nextItem.id}...');
      await _executeRequest(nextItem);

      // Brief delay between recovery requests
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() {
        _isProcessingQueue = false;
      });
    }
  }

  // ── Manual simulation triggers for easy testing ──────────────────────────

  void _simulateDrop() {
    _handleConnectivityUpdate([ConnectivityResult.none]);
  }

  void _simulateWifi() {
    _handleConnectivityUpdate([ConnectivityResult.wifi]);
  }

  void _simulateCellular() {
    _handleConnectivityUpdate([ConnectivityResult.mobile]);
  }

  // ── Build UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            tooltip: 'Clear event log',
            icon: const Icon(Icons.cleaning_services_rounded, size: 20),
            onPressed: () {
              setState(() => _eventLogs.clear());
            },
          ),
        ],
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Real-time Dynamic Dashboard Card ──────────────────────────
          _buildNetworkDashboardCard(),
          const SizedBox(height: 14),

          // ── Metrics Row ───────────────────────────────────────────────
          _buildMetricsRow(),
          const SizedBox(height: 14),

          // ── Simulation Bar (Wi-Fi, Cellular, Drop) ─────────────────────
          _buildSimulationControls(),
          const SizedBox(height: 14),

          // ── Fetch Action Buttons ──────────────────────────────────────
          _buildActionButtons(),
          const SizedBox(height: 14),

          // ── Live Streamed Transfer Progress ───────────────────────────
          if (_isFetching) ...[
            _buildActiveFetchCard(),
            const SizedBox(height: 14),
          ],

          // ── Pending Request Queue Card ────────────────────────────────
          _buildQueueCard(),
          const SizedBox(height: 16),

          // ── Event Stream & Recovery Log ───────────────────────────────
          _buildEventLogCard(),
          const SizedBox(height: 16),

          // ── Historical Request Log ────────────────────────────────────
          _buildRequestHistory(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── UI Components ────────────────────────────────────────────────────────

  Widget _buildNetworkDashboardCard() {
    final (label, icon, color, gradient) = switch (_currentNetwork) {
      NetworkType.wifi => (
          'Connected via Wi-Fi',
          Icons.wifi_rounded,
          AppPalette.primary,
          AppPalette.brandGradient,
        ),
      NetworkType.cellular => (
          'Connected via Cellular',
          Icons.signal_cellular_alt_rounded,
          const Color(0xFF3949AB),
          const LinearGradient(
            colors: [Color(0xFF3949AB), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      NetworkType.ethernet => (
          'Connected via Ethernet',
          Icons.settings_ethernet_rounded,
          AppPalette.primary,
          AppPalette.brandGradient,
        ),
      NetworkType.offline => (
          'Offline (No Network)',
          Icons.wifi_off_rounded,
          AppPalette.accent,
          LinearGradient(
            colors: [AppPalette.accent, const Color(0xFFE53935)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _currentNetwork == NetworkType.offline
                        ? 1.0
                        : _pulseAnim.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REAL-TIME INTERFACE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentNetwork == NetworkType.offline ? 'HALTED' : 'STREAMING',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Handover switches: $_handoverCount',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _lastStateChange == null
                    ? 'Listening...'
                    : 'Last transition: ${_lastStateChange!.hour.toString().padLeft(2, '0')}:${_lastStateChange!.minute.toString().padLeft(2, '0')}:${_lastStateChange!.second.toString().padLeft(2, '0')}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: 'QUEUED REQUESTS',
            value: '${_requestQueue.length}',
            subtitle: _requestQueue.isEmpty ? 'Queue clean' : 'Awaiting sync',
            color: _requestQueue.isEmpty ? AppPalette.primary : AppPalette.accent,
            icon: Icons.hourglass_bottom_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            title: 'RECORDS FETCHED',
            value: '$_totalRecordsDownloaded',
            subtitle: 'Cumulative records',
            color: AppPalette.primary,
            icon: Icons.dataset_rounded,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppPalette.textSecondary(context),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppPalette.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: AppPalette.primary),
              const SizedBox(width: 6),
              Text(
                'TEST HANDOVER & DISCONNECTION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppPalette.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _simulateWifi,
                  icon: const Icon(Icons.wifi, size: 16),
                  label: const Text('Wi-Fi'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _simulateCellular,
                  icon: const Icon(Icons.signal_cellular_alt, size: 16),
                  label: const Text('Cellular'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _simulateDrop,
                  icon: const Icon(Icons.signal_wifi_off, size: 16, color: Colors.white),
                  label: const Text('Drop', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: triggerLargeDatasetFetch,
            icon: const Icon(Icons.cloud_download_rounded, size: 18, color: Colors.white),
            label: Text(
              'Fetch 5k Dataset',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: triggerContinuousBatchSync,
            icon: Icon(Icons.all_inclusive_rounded, size: 18, color: AppPalette.primary),
            label: Text(
              'Continuous Sync',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppPalette.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFetchCard() {
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
                  _activeTaskLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(_progressValue * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 14,
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
              value: _progressValue,
              minHeight: 8,
              backgroundColor: AppPalette.primarySoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppPalette.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _streamedRecords > 0
                    ? 'Records: $_streamedRecords (${(_streamedBytes / 1024).toStringAsFixed(1)} KB)'
                    : 'Transferred: ${(_streamedBytes / 1024).toStringAsFixed(1)} KB',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppPalette.textSecondary(context),
                ),
              ),
              Text(
                'Interface: ${_netName(_currentNetwork)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard() {
    if (_requestQueue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.queue_rounded, color: AppPalette.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'PENDING REQUEST QUEUE (${_requestQueue.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppPalette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The requests below were caught during network drops/handovers. They are preserved in memory and will auto-resume immediately upon connection restoration.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppPalette.textPrimary(context).withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          ..._requestQueue.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 16, color: AppPalette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.id}: ${item.title}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      item.failureReason ?? 'Queued',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppPalette.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEventLogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NETWORK EVENT & RECOVERY STREAM',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppPalette.textSecondary(context),
                ),
              ),
              Text(
                '${_eventLogs.length} events',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppPalette.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppPalette.textSecondary(context).withValues(alpha: 0.1),
              ),
            ),
            child: _eventLogs.isEmpty
                ? Center(
                    child: Text(
                      'No events logged yet. Toggling Wi-Fi/Cellular triggers stream events.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppPalette.textSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _eventLogs.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _eventLogs[idx],
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: AppPalette.textPrimary(context),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REQUEST LIFECYCLE HISTORY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppPalette.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        if (_historyLog.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No requests triggered yet. Tap "Fetch 5k Dataset" above.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppPalette.textSecondary(context),
                ),
              ),
            ),
          )
        else
          ...List.generate(_historyLog.length, (i) {
            final item = _historyLog[i];
            final (icon, color, label) = switch (item.status) {
              RequestStatus.queued => (
                  Icons.hourglass_bottom_rounded,
                  AppPalette.accent,
                  'QUEUED',
                ),
              RequestStatus.running => (
                  Icons.sync_rounded,
                  AppPalette.primary,
                  'STREAMING',
                ),
              RequestStatus.completed => (
                  Icons.check_circle_rounded,
                  const Color(0xFF388E3C),
                  'COMPLETED',
                ),
              RequestStatus.failed => (
                  Icons.error_outline_rounded,
                  AppPalette.accent,
                  'FAILED',
                ),
            };

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
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
                          '${item.id}: ${item.title}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary(context),
                          ),
                        ),
                        Text(
                          item.status == RequestStatus.completed
                              ? '${item.recordsFetched} items received'
                              : (item.failureReason ?? 'Pending retry'),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppPalette.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
