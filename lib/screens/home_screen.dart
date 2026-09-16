import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/activity_registry.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_card.dart';
import '../widgets/motion.dart';
import 'settings_screen.dart';

// HomeScreen — Route host for the 2 fixed bottom tabs (Home and Settings).
// Activities open exclusively via Navigator.push from the registry list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildHomeDashboard(context, user),
            const SettingsScreen(isEmbedded: true),
          ],
        ),
      ),
      // Exactly 2 fixed tabs: Home & Settings
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface(context),
          boxShadow: AppPalette.cardShadow(context),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor: AppPalette.surface(context),
          selectedItemColor: AppPalette.primary,
          unselectedItemColor: AppPalette.textSecondary(context),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context, UserProvider user) {
    final avatarLetter =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'S';

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Composed Header Row (Priority 4) ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar in rounded squircle chip
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(48 * 0.32),
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Two-tier text hierarchy: small muted eyebrow above bold name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WELCOME BACK',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppPalette.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.textPrimary(context),
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Accented emoji in a small tinted circle badge
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppPalette.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '👋',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Single Brand Gradient Hero Banner ─────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppPalette.brandGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'SEMESTER COMPILATION',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.science_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Activity Hub',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${labActivities.length} lab activities ready to explore',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Section Title ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'LAB ACTIVITIES',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppPalette.textSecondary(context),
            ),
          ),
        ),

        // ── Staggered Entrance Activities List ────────────────────────
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: labActivities.length,
          itemBuilder: (context, index) {
            final activity = labActivities[index];
            return FadeSlideEntrance(
              index: index,
              child: ActivityCard(
                activity: activity,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: activity.builder),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
