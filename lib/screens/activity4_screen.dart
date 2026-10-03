import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mesh_chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity 4 — Local Mesh Chat (Serverless P2P via Nearby Connections)
//
// Layout:
//   • Mesh Control Banner  — Start/Stop, device name, status
//   • Pending Requests     — Accept / Reject incoming handshakes
//   • Discovered Peers     — Tap to connect
//   • Connected Peers      — Active connections
//   • Chat Panel           — Message bubbles + input field
// ─────────────────────────────────────────────────────────────────────────────

class Activity4Screen extends StatefulWidget {
  const Activity4Screen({super.key});

  @override
  State<Activity4Screen> createState() => _Activity4ScreenState();
}

class _Activity4ScreenState extends State<Activity4Screen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String? _selectedPeerId; // which peer to message directly (null = broadcast)

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(MeshChatProvider provider) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _msgCtrl.clear();

    if (_selectedPeerId != null) {
      await provider.sendMessage(_selectedPeerId!, text);
    } else {
      await provider.broadcast(text);
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Activity 4 — Local Mesh Chat',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppPalette.textPrimary(context),
          ),
        ),
        actions: [
          Consumer<MeshChatProvider>(
            builder: (context, provider, _) => IconButton(
              tooltip: 'Clear messages',
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              color: AppPalette.textSecondary(context),
              onPressed: provider.messages.isEmpty
                  ? null
                  : () {
                      provider.clearMessages();
                    },
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: Consumer<MeshChatProvider>(
        builder: (context, provider, _) {
          // Scroll down whenever messages update
          if (provider.messages.isNotEmpty) _scrollToBottom();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  children: [
                    // 1. Control Panel
                    _MeshControlPanel(provider: provider),
                    const SizedBox(height: 14),

                    // 2. Pending Handshake Requests
                    if (provider.pendingPeers.isNotEmpty) ...[
                      _PendingRequestsCard(provider: provider),
                      const SizedBox(height: 14),
                    ],

                    // 3. Discovered Peers (not yet connected)
                    if (provider.discoveredPeers.isNotEmpty) ...[
                      _DiscoveredPeersCard(
                        provider: provider,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. Connected Peers
                    if (provider.connectedPeers.isNotEmpty) ...[
                      _ConnectedPeersCard(
                        provider: provider,
                        selectedPeerId: _selectedPeerId,
                        onSelectPeer: (id) => setState(
                            () => _selectedPeerId =
                                _selectedPeerId == id ? null : id),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 5. Chat Messages
                    _ChatMessageList(
                      provider: provider,
                      scrollCtrl: _scrollCtrl,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // 6. Message Input Bar
              if (provider.connectedPeers.isNotEmpty)
                _ChatInputBar(
                  controller: _msgCtrl,
                  provider: provider,
                  selectedPeerId: _selectedPeerId,
                  onSend: () => _sendMessage(provider),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1. Mesh Control Panel ────────────────────────────────────────────────────

class _MeshControlPanel extends StatelessWidget {
  final MeshChatProvider provider;
  const _MeshControlPanel({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isActive = provider.isMeshActive;
    final isStarting = provider.status == MeshStatus.starting;

    final (gradientColors, statusText, icon) = isActive
        ? (
            [AppPalette.primary, AppPalette.primaryDeep],
            'Mesh Active — Broadcasting & Scanning',
            Icons.hub_rounded,
          )
        : provider.status == MeshStatus.error
            ? (
                [AppPalette.accent, const Color(0xFFD32F2F)],
                provider.lastError ?? 'Error',
                Icons.error_outline_rounded,
              )
            : (
                [const Color(0xFF546E7A), const Color(0xFF37474F)],
                'Mesh Offline — Tap Start to discover peers',
                Icons.hub_outlined,
              );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCAL MESH CHAT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.userName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Start / Stop button
              TapScale(
                onTap: isStarting
                    ? () {}
                    : isActive
                        ? () => provider.stopMesh()
                        : () => provider.startMesh(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Stop' : 'Start',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _StatusPill(
                    icon: Icons.campaign_rounded,
                    label: 'Advertising',
                    active: provider.isAdvertising),
                const SizedBox(width: 8),
                _StatusPill(
                    icon: Icons.search_rounded,
                    label: 'Discovering',
                    active: provider.isDiscovering),
                const SizedBox(width: 8),
                _StatusPill(
                    icon: Icons.people_rounded,
                    label: '${provider.connectedPeers.length} connected',
                    active: provider.connectedPeers.isNotEmpty),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _StatusPill(
      {required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Pending Handshake Requests ────────────────────────────────────────────

class _PendingRequestsCard extends StatelessWidget {
  final MeshChatProvider provider;
  const _PendingRequestsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_rounded,
                  color: AppPalette.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'INCOMING CONNECTION REQUESTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppPalette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...provider.pendingPeers.map((peer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppPalette.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 18, color: AppPalette.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        peer.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary(context),
                        ),
                      ),
                    ),
                    // Reject
                    OutlinedButton(
                      onPressed: () => provider.rejectPeer(peer.endpointId),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppPalette.accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reject',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.accent)),
                    ),
                    const SizedBox(width: 8),
                    // Accept
                    ElevatedButton(
                      onPressed: () => provider.acceptPeer(peer.endpointId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Accept',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── 3. Discovered Peers ──────────────────────────────────────────────────────

class _DiscoveredPeersCard extends StatelessWidget {
  final MeshChatProvider provider;
  const _DiscoveredPeersCard({required this.provider});

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.radar_rounded,
                  color: AppPalette.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'NEARBY DEVICES (${provider.discoveredPeers.length})',
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
          ...provider.discoveredPeers.map((peer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smartphone_rounded,
                          size: 18, color: AppPalette.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        peer.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary(context),
                        ),
                      ),
                    ),
                    TapScale(
                      onTap: () => provider.requestConnection(peer.endpointId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppPalette.brandGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Connect',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── 4. Connected Peers ───────────────────────────────────────────────────────

class _ConnectedPeersCard extends StatelessWidget {
  final MeshChatProvider provider;
  final String? selectedPeerId;
  final ValueChanged<String> onSelectPeer;

  const _ConnectedPeersCard({
    required this.provider,
    required this.selectedPeerId,
    required this.onSelectPeer,
  });

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.people_alt_rounded,
                  color: AppPalette.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'CONNECTED PEERS (${provider.connectedPeers.length})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppPalette.textSecondary(context),
                ),
              ),
              const Spacer(),
              if (selectedPeerId != null)
                GestureDetector(
                  onTap: () => onSelectPeer(selectedPeerId!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Broadcast mode',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...provider.connectedPeers.map((peer) {
            final isSelected = selectedPeerId == peer.endpointId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TapScale(
                onTap: () => onSelectPeer(peer.endpointId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppPalette.primarySoft
                        : AppPalette.background(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppPalette.primary.withValues(alpha: 0.4)
                          : AppPalette.textSecondary(context)
                              .withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 16, color: AppPalette.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          peer.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppPalette.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DIRECT',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: const Color(0xFF43A047),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              selectedPeerId == null
                  ? 'Tap a peer to send direct messages, or leave unselected to broadcast to all.'
                  : 'Sending directly to ${provider.connectedPeers.firstWhere((p) => p.endpointId == selectedPeerId, orElse: () => PeerInfo(endpointId: '', name: '?')).name}. Tap again to switch to broadcast.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppPalette.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Chat Message List ──────────────────────────────────────────────────────

class _ChatMessageList extends StatelessWidget {
  final MeshChatProvider provider;
  final ScrollController scrollCtrl;

  const _ChatMessageList({
    required this.provider,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final messages = provider.messages;

    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 52,
                color: AppPalette.textSecondary(context).withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                provider.isMeshActive
                    ? 'Waiting for a peer to connect...'
                    : 'Start the mesh to discover nearby devices',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppPalette.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'MESSAGES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppPalette.textSecondary(context),
            ),
          ),
        ),
        ...List.generate(messages.length, (i) {
          final msg = messages[i];
          return FadeSlideEntrance(
            index: i,
            child: _MessageBubble(message: msg),
          );
        }),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    // System messages (connect/disconnect events) centered
    if (message.senderId == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppPalette.textSecondary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppPalette.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            // Peer avatar
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppPalette.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.senderName.isNotEmpty
                      ? message.senderName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textSecondary(context),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppPalette.primary : AppPalette.surface(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: AppPalette.cardShadow(context),
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isMe
                          ? Colors.white
                          : AppPalette.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppPalette.textSecondary(context)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── 6. Chat Input Bar ─────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final MeshChatProvider provider;
  final String? selectedPeerId;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.provider,
    required this.selectedPeerId,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppPalette.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: selectedPeerId == null
                    ? 'Broadcast to all peers...'
                    : 'Message ${provider.connectedPeers.firstWhere((p) => p.endpointId == selectedPeerId, orElse: () => PeerInfo(endpointId: '', name: 'peer')).name}...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppPalette.textSecondary(context),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TapScale(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
