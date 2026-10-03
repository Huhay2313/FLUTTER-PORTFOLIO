import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MeshChatProvider — global ChangeNotifier for peer-to-peer mesh chat
//
// Architecture:
//   1. startMesh()  → request permissions, then startAdvertising + startDiscovery
//   2. When a peer is found  → add to discoveredPeers, notify UI
//   3. requestConnection()   → initiates the Nearby handshake
//   4. acceptPeer()          → both sides accept → encrypted P2P channel open
//   5. sendMessage()         → encodes text as UTF-8 bytes → sendBytesPayload
//   6. onPayloadReceived     → decodes bytes → appends ChatMessage → notifyListeners
//   7. stopMesh()            → stops advertising/discovery, disconnects all
// ─────────────────────────────────────────────────────────────────────────────

enum MeshStatus { idle, starting, active, error }

class ChatMessage {
  final String id;
  final String senderId;   // 'me' or endpointId
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}

class PeerInfo {
  final String endpointId;
  final String name;
  bool isConnected;
  bool isPending; // waiting for acceptConnection

  PeerInfo({
    required this.endpointId,
    required this.name,
    this.isConnected = false,
    this.isPending = false,
  });
}

class MeshChatProvider extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────
  MeshStatus _status = MeshStatus.idle;
  String _userName = 'Device';
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _lastError;

  // endpointId → PeerInfo
  final Map<String, PeerInfo> _peers = {};

  // All chat messages (across all peers)
  final List<ChatMessage> _messages = [];

  // ── Public Getters ────────────────────────────────────────────────────────
  MeshStatus get status => _status;
  String get userName => _userName;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  String? get lastError => _lastError;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  List<PeerInfo> get discoveredPeers =>
      _peers.values.where((p) => !p.isConnected && !p.isPending).toList();
  List<PeerInfo> get pendingPeers =>
      _peers.values.where((p) => p.isPending).toList();
  List<PeerInfo> get connectedPeers =>
      _peers.values.where((p) => p.isConnected).toList();

  int get totalPeerCount => _peers.length;
  bool get isMeshActive => _isAdvertising || _isDiscovering;

  void setUserName(String name) {
    _userName = name.trim().isEmpty ? 'Device' : name.trim();
    notifyListeners();
  }

  // ── Permission Check ──────────────────────────────────────────────────────

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();
    final allGranted = statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );

    if (!allGranted) {
      _lastError =
          'Permissions denied. Enable Bluetooth + Location in Settings.';
      notifyListeners();
    }
    return allGranted;
  }

  // ── Start Mesh ────────────────────────────────────────────────────────────

  /// Starts both advertising (broadcasting presence) and discovering
  /// (scanning for nearby peers) simultaneously using P2P_CLUSTER strategy,
  /// which enables a true multi-device mesh topology.
  Future<void> startMesh() async {
    if (isMeshActive) return;

    _status = MeshStatus.starting;
    _lastError = null;
    notifyListeners();

    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      _status = MeshStatus.error;
      notifyListeners();
      return;
    }

    try {
      await _startAdvertising();
      await _startDiscovery();
      _status = MeshStatus.active;
    } catch (e) {
      _lastError = 'Failed to start mesh: $e';
      _status = MeshStatus.error;
    }
    notifyListeners();
  }

  Future<void> _startAdvertising() async {
    await Nearby().startAdvertising(
      _userName,
      Strategy.P2P_CLUSTER,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
    _isAdvertising = true;
  }

  Future<void> _startDiscovery() async {
    await Nearby().startDiscovery(
      _userName,
      Strategy.P2P_CLUSTER,
      onEndpointFound: _onEndpointFound,
      onEndpointLost: _onEndpointLost,
    );
    _isDiscovering = true;
  }

  // ── Stop Mesh ─────────────────────────────────────────────────────────────

  Future<void> stopMesh() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}

    _isAdvertising = false;
    _isDiscovering = false;
    _peers.clear();
    _status = MeshStatus.idle;
    notifyListeners();
  }

  // ── Discovery Callbacks ───────────────────────────────────────────────────

  /// Called when a nearby device broadcasting the same service is found.
  void _onEndpointFound(String endpointId, String endpointName, String serviceId) {
    if (!_peers.containsKey(endpointId)) {
      _peers[endpointId] = PeerInfo(
        endpointId: endpointId,
        name: endpointName,
      );
      notifyListeners();
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null && _peers.containsKey(endpointId)) {
      if (!_peers[endpointId]!.isConnected) {
        _peers.remove(endpointId);
        notifyListeners();
      }
    }
  }

  // ── Connection Handshake ──────────────────────────────────────────────────

  /// Initiates a pairing request to a discovered endpoint.
  Future<void> requestConnection(String endpointId) async {
    try {
      await Nearby().requestConnection(
        _userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      _peers[endpointId]?.isPending = true;
      notifyListeners();
    } catch (e) {
      _lastError = 'Connection request failed: $e';
      notifyListeners();
    }
  }

  /// Called on BOTH devices when a connection handshake is initiated.
  /// We auto-accept on the advertising side; the UI calls acceptPeer() manually.
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Add as pending if not already known
    _peers.putIfAbsent(
      endpointId,
      () => PeerInfo(endpointId: endpointId, name: info.endpointName),
    );
    _peers[endpointId]!.isPending = true;
    notifyListeners();
  }

  /// Accepts a pending pairing request — called from the UI when the user
  /// taps "Accept" on the handshake dialog.
  Future<void> acceptPeer(String endpointId) async {
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
    } catch (e) {
      _lastError = 'Accept failed: $e';
      notifyListeners();
    }
  }

  Future<void> rejectPeer(String endpointId) async {
    try {
      await Nearby().rejectConnection(endpointId);
    } catch (_) {}
    _peers.remove(endpointId);
    notifyListeners();
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _peers[endpointId]?.isConnected = true;
      _peers[endpointId]?.isPending = false;

      // System message in chat
      final peer = _peers[endpointId];
      _appendSystemMessage('✅ Connected to ${peer?.name ?? endpointId}');
    } else {
      _peers.remove(endpointId);
      _appendSystemMessage('❌ Connection to $endpointId failed');
    }
    notifyListeners();
  }

  void _onDisconnected(String endpointId) {
    final name = _peers[endpointId]?.name ?? endpointId;
    _peers.remove(endpointId);
    _appendSystemMessage('🔌 $name disconnected');
    notifyListeners();
  }

  // ── Payload (Messages) ────────────────────────────────────────────────────

  /// Sends a text message to a specific peer.
  Future<void> sendMessage(String endpointId, String text) async {
    if (text.trim().isEmpty) return;
    final peer = _peers[endpointId];
    if (peer == null || !peer.isConnected) return;

    final payload = Uint8List.fromList(utf8.encode(text.trim()));
    try {
      await Nearby().sendBytesPayload(endpointId, payload);
      _messages.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'me',
        senderName: _userName,
        text: text.trim(),
        timestamp: DateTime.now(),
        isMe: true,
      ));
      notifyListeners();
    } catch (e) {
      _lastError = 'Send failed: $e';
      notifyListeners();
    }
  }

  /// Broadcasts a text message to ALL connected peers.
  Future<void> broadcast(String text) async {
    if (text.trim().isEmpty) return;
    final connected = connectedPeers;
    if (connected.isEmpty) return;

    final payload = Uint8List.fromList(utf8.encode(text.trim()));
    for (final peer in connected) {
      try {
        await Nearby().sendBytesPayload(peer.endpointId, payload);
      } catch (_) {}
    }
    _messages.add(ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: _userName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    ));
    notifyListeners();
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final text = utf8.decode(payload.bytes!);
      final sender = _peers[endpointId];
      _messages.add(ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_$endpointId',
        senderId: endpointId,
        senderName: sender?.name ?? endpointId,
        text: text,
        timestamp: DateTime.now(),
        isMe: false,
      ));
      notifyListeners();
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // We use byte payloads which transfer atomically — no chunking needed
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _appendSystemMessage(String text) {
    _messages.add(ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_sys',
      senderId: 'system',
      senderName: 'System',
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
    ));
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
