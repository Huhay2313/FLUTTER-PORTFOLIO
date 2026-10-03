import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/network_health_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity 3 — Network Diagnostic Dashboard
//
// Reads NetworkHealthProvider (global state) and adapts its UI dynamically:
//   Excellent → Full HD hero card, rich gradient stats
//   Fair      → Standard card, normal detail
//   Poor      → Lightweight text-only placeholder
//   Degraded  → Grey shimmer, warning banner, manual retry
// ─────────────────────────────────────────────────────────────────────────────

class Activity3Screen extends StatelessWidget {
  const Activity3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Activity 3 — Network Diagnostics',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppPalette.textPrimary(context),
          ),
        ),
        actions: [
          // Manual re-run button
          Consumer<NetworkHealthProvider>(
            builder: (context, provider, _) {
              return IconButton(
                tooltip: 'Re-run diagnostic',
                onPressed: provider.isDiagnosticRunning
                    ? null
                    : () => context.read<NetworkHealthProvider>().runDiagnostic(),
                icon: provider.isDiagnosticRunning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppPalette.primary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppPalette.primary),
              );
            },
          ),
        ],
        centerTitle: false,
      ),
      body: Consumer<NetworkHealthProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Health Tier Banner
              _TierBanner(provider: provider),
              const SizedBox(height: 14),

              // 2. Metrics Grid (4 chips)
              _MetricsGrid(provider: provider),
              const SizedBox(height: 14),

              // 3. Animated 3-phase Diagnostic Stepper
              _DiagnosticStepper(provider: provider),
              const SizedBox(height: 14),

              // 4. Adaptive Media Card (core demo of the activity)
              _AdaptiveMediaCard(tier: provider.currentTier),
              const SizedBox(height: 14),

              // 5. Diagnostic History
              _DiagnosticHistory(provider: provider),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Tier colour mapping ──────────────────────────────────────────────────────

extension _TierColors on NetworkTier {
  Color get primary {
    switch (this) {
      case NetworkTier.excellent:
        return const Color(0xFF00897B); // teal
      case NetworkTier.fair:
        return const Color(0xFF1E88E5); // blue
      case NetworkTier.poor:
        return const Color(0xFFF57C00); // amber
      case NetworkTier.degraded:
        return const Color(0xFFD32F2F); // red
    }
  }

  Color get deep {
    switch (this) {
      case NetworkTier.excellent:
        return const Color(0xFF005B52);
      case NetworkTier.fair:
        return const Color(0xFF0D47A1);
      case NetworkTier.poor:
        return const Color(0xFFE65100);
      case NetworkTier.degraded:
        return const Color(0xFFB71C1C);
    }
  }

  LinearGradient get gradient => LinearGradient(
        colors: [primary, deep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  IconData get icon {
    switch (this) {
      case NetworkTier.excellent:
        return Icons.signal_wifi_4_bar_rounded;
      case NetworkTier.fair:
        return Icons.network_wifi_2_bar_rounded;
      case NetworkTier.poor:
        return Icons.network_wifi_1_bar_rounded;
      case NetworkTier.degraded:
        return Icons.signal_wifi_off_rounded;
    }
  }

  String get label {
    switch (this) {
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

  String get description {
    switch (this) {
      case NetworkTier.excellent:
        return 'Download > 10 Mbps, Ping < 50 ms\nHigh-resolution media active';
      case NetworkTier.fair:
        return 'Download 2–10 Mbps or Ping 50–150 ms\nStandard quality active';
      case NetworkTier.poor:
        return 'Download < 2 Mbps or Ping 150–400 ms\nLightweight placeholders active';
      case NetworkTier.degraded:
        return 'Ping > 400 ms or packet loss detected\nOffline-mode placeholders active';
    }
  }
}

// ── 1. Tier Banner ───────────────────────────────────────────────────────────

class _TierBanner extends StatelessWidget {
  final NetworkHealthProvider provider;
  const _TierBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tier = provider.currentTier;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: tier.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tier.primary.withValues(alpha: 0.35),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(tier.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONNECTION HEALTH',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tier.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Auto / Manual badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.isDiagnosticRunning ? 'SCANNING' : 'LIVE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tier.description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            provider.statusMessage,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white70,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Metrics Grid ──────────────────────────────────────────────────────────

class _MetricsGrid extends StatelessWidget {
  final NetworkHealthProvider provider;
  const _MetricsGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = provider.latestSnapshot;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricChip(
                icon: Icons.timer_outlined,
                label: 'IDLE PING',
                value: s == null ? '—' : '${s.idlePingMs} ms',
                color: _pingColor(s?.idlePingMs),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricChip(
                icon: Icons.download_rounded,
                label: 'DOWNLOAD',
                value: s == null ? '—' : '${s.downloadMbps} Mbps',
                color: _speedColor(s?.downloadMbps),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricChip(
                icon: Icons.upload_rounded,
                label: 'UPLOAD',
                value: s == null ? '—' : '${s.uploadMbps} Mbps',
                color: _speedColor(s?.uploadMbps),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricChip(
                icon: Icons.swap_vert_rounded,
                label: 'UPLOAD PING',
                value: s == null ? '—' : '${s.uploadPingMs} ms',
                color: _pingColor(s?.uploadPingMs),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _pingColor(int? ms) {
    if (ms == null) return AppPalette.primary;
    if (ms < 50) return const Color(0xFF388E3C);
    if (ms < 150) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }

  Color _speedColor(double? mbps) {
    if (mbps == null) return AppPalette.primary;
    if (mbps > 10) return const Color(0xFF388E3C);
    if (mbps >= 2) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
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

// ── 3. Diagnostic Stepper ────────────────────────────────────────────────────

class _DiagnosticStepper extends StatelessWidget {
  final NetworkHealthProvider provider;
  const _DiagnosticStepper({required this.provider});

  @override
  Widget build(BuildContext context) {
    final phase = provider.currentPhase;

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
          Text(
            'DIAGNOSTIC SEQUENCE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppPalette.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          _StepRow(
            stepNumber: 1,
            title: 'Baseline Idle Ping',
            subtitle: 'TCP socket to 1.1.1.1 × 5 samples',
            isActive: phase == DiagnosticPhase.phase1Ping,
            isDone: _isDone(phase, DiagnosticPhase.phase1Ping),
          ),
          _StepConnector(),
          _StepRow(
            stepNumber: 2,
            title: 'Download Speed + Concurrent Ping',
            subtitle: '5 MB download via Cloudflare speed test',
            isActive: phase == DiagnosticPhase.phase2Download,
            isDone: _isDone(phase, DiagnosticPhase.phase2Download),
          ),
          _StepConnector(),
          _StepRow(
            stepNumber: 3,
            title: 'Upload Speed + Concurrent Ping',
            subtitle: '512 KB upload to httpbin.org/post',
            isActive: phase == DiagnosticPhase.phase3Upload,
            isDone: _isDone(phase, DiagnosticPhase.phase3Upload),
          ),
        ],
      ),
    );
  }

  bool _isDone(DiagnosticPhase current, DiagnosticPhase step) {
    final order = [
      DiagnosticPhase.idle,
      DiagnosticPhase.phase1Ping,
      DiagnosticPhase.phase2Download,
      DiagnosticPhase.phase3Upload,
      DiagnosticPhase.done,
    ];
    return order.indexOf(current) > order.indexOf(step);
  }
}

class _StepConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 18),
        width: 2,
        height: 16,
        color: AppPalette.textSecondary(context).withValues(alpha: 0.15),
      );
}

class _StepRow extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final bool isActive;
  final bool isDone;

  const _StepRow({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? const Color(0xFF388E3C)
        : isActive
            ? AppPalette.primary
            : AppPalette.textSecondary(context).withValues(alpha: 0.4);

    return Row(
      children: [
        // Step dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDone || isActive ? 0.12 : 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check_rounded, size: 18, color: color)
                : isActive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.primary,
                        ),
                      )
                    : Text(
                        '$stepNumber',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive || isDone
                      ? AppPalette.textPrimary(context)
                      : AppPalette.textSecondary(context),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppPalette.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 4. Adaptive Media Card ───────────────────────────────────────────────────

class _AdaptiveMediaCard extends StatelessWidget {
  final NetworkTier tier;
  const _AdaptiveMediaCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ADAPTIVE MEDIA RENDERING',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: AppPalette.textSecondary(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tier.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tier.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: tier.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _tierCard(context, tier),
        ),
      ],
    );
  }

  Widget _tierCard(BuildContext context, NetworkTier tier) {
    switch (tier) {
      case NetworkTier.excellent:
        return _ExcellentCard(key: const ValueKey('excellent'));
      case NetworkTier.fair:
        return _FairCard(key: const ValueKey('fair'));
      case NetworkTier.poor:
        return _PoorCard(key: const ValueKey('poor'));
      case NetworkTier.degraded:
        return _DegradedCard(key: const ValueKey('degraded'));
    }
  }
}

// Full HD hero card — shown on Excellent
class _ExcellentCard extends StatelessWidget {
  const _ExcellentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF005B52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-res simulated image area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF26A69A), Color(0xFF00BCD4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.hd_rounded,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    left: 12,
                    child: _HDBadge(),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Icon(Icons.speed_rounded,
                            color: Colors.white.withValues(alpha: 0.9), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Full Resolution Active',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High-Resolution Stream',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '4K video, lossless audio, real-time updates — all enabled at Excellent tier.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatPill(label: '4K', icon: Icons.hd_rounded),
                    const SizedBox(width: 8),
                    _StatPill(label: 'Lossless', icon: Icons.music_note_rounded),
                    const SizedBox(width: 8),
                    _StatPill(label: 'Live', icon: Icons.circle, iconColor: Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HDBadge extends StatelessWidget {
  const _HDBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '4K • FULL HD',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;

  const _StatPill({
    required this.label,
    required this.icon,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Standard card — Fair tier
class _FairCard extends StatelessWidget {
  const _FairCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.4)),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medium-res simulated image area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: Container(
              height: 110,
              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sd_rounded,
                        size: 44, color: const Color(0xFF1E88E5).withValues(alpha: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      'STANDARD QUALITY',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: const Color(0xFF1E88E5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standard Quality Stream',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary(context),
                    )),
                const SizedBox(height: 4),
                Text(
                  '720p video, compressed audio. Reduced update frequency.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppPalette.textSecondary(context),
                    height: 1.5,
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

// Text-only lightweight — Poor tier
class _PoorCard extends StatelessWidget {
  const _PoorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF57C00).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF57C00).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.image_not_supported_rounded,
                size: 28, color: Color(0xFFF57C00)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lightweight Mode',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary(context),
                    )),
                const SizedBox(height: 4),
                Text(
                  'Images replaced with placeholders.\nText-only content loaded.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppPalette.textSecondary(context),
                    height: 1.5,
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

// Shimmer offline — Degraded tier
class _DegradedCard extends StatelessWidget {
  const _DegradedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.4)),
        boxShadow: AppPalette.cardShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 28, color: Color(0xFFD32F2F)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offline Placeholder',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary(context),
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Connection degraded or packet loss.\nAll media replaced with cached stubs.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppPalette.textSecondary(context),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Shimmer rows to simulate cached offline placeholders
          ...[0.8, 0.6, 0.4].map(
            (width) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 12,
              decoration: BoxDecoration(
                color: AppPalette.textSecondary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.textSecondary(context).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Diagnostic History ─────────────────────────────────────────────────────

class _DiagnosticHistory extends StatelessWidget {
  final NetworkHealthProvider provider;
  const _DiagnosticHistory({required this.provider});

  @override
  Widget build(BuildContext context) {
    final history = provider.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIAGNOSTIC HISTORY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: AppPalette.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No diagnostic runs yet — first scan in progress',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppPalette.textSecondary(context),
                ),
              ),
            ),
          )
        else
          ...List.generate(history.length, (i) {
            final s = history[i];
            return FadeSlideEntrance(
              index: i,
              child: _HistoryTile(snapshot: s),
            );
          }),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DiagnosticSnapshot snapshot;
  const _HistoryTile({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final tier = snapshot.tier;
    final timeStr =
        '${snapshot.timestamp.hour.toString().padLeft(2, '0')}:${snapshot.timestamp.minute.toString().padLeft(2, '0')}:${snapshot.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              color: tier.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(tier.icon, size: 18, color: tier.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$timeStr — ${snapshot.tierLabel}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
                Text(
                  '↓ ${snapshot.downloadMbps} Mbps  ↑ ${snapshot.uploadMbps} Mbps  Ping: ${snapshot.idlePingMs} ms',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppPalette.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tier.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tier.label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: tier.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
