import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

// SettingsScreen — StatefulWidget managing user profile and global appearance.
// Changes commit directly to Providers with haptics and snackbar confirmation.
class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: context.read<UserProvider>().name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveName() {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    context.read<UserProvider>().updateName(newName);
    FocusScope.of(context).unfocus();
    showAppSnackbar(
      context,
      message: 'Profile name updated',
      icon: Icons.check_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeP = context.watch<ThemeProvider>();
    final userP = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: AppPalette.background(context),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppPalette.textPrimary(context),
                ),
              ),
              centerTitle: false,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.isEmbedded) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: AppPalette.textPrimary(context),
                ),
              ),
            ),
          ],

          // ── Single Brand Gradient Hero Banner ─────────────────────
          Container(
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
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(52 * 0.32),
                  ),
                  child: Center(
                    child: Text(
                      userP.name.isNotEmpty
                          ? userP.name[0].toUpperCase()
                          : 'S',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userP.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student Profile',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Profile Section Card ─────────────────────────────────────
          _sectionTitle(context, 'PROFILE INFO'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppPalette.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveName(),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: GoogleFonts.inter(
                            color: AppPalette.textSecondary(context),
                          ),
                          filled: true,
                          fillColor: AppPalette.background(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Squircle save chip with micro-interaction
                    TapScale(
                      onTap: _saveName,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppPalette.primary,
                          borderRadius: BorderRadius.circular(46 * 0.32),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Appearance Section Card ──────────────────────────────────
          _sectionTitle(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppPalette.cardShadow(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(44 * 0.32),
                  ),
                  child: Icon(
                    themeP.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppPalette.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Theme',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        themeP.isDark ? 'Enabled' : 'Disabled',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppPalette.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: themeP.isDark,
                  onChanged: (_) {
                    HapticFeedback.lightImpact();
                    context.read<ThemeProvider>().toggleTheme();
                  },
                  activeTrackColor: AppPalette.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── About Section Card ───────────────────────────────────────
          _sectionTitle(context, 'ABOUT LABHUB'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppPalette.cardShadow(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(44 * 0.32),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: AppPalette.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LabHub v1.0.0',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Master compilation dashboard for semester lab activities.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppPalette.textSecondary(context),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppPalette.textSecondary(context),
        ),
      ),
    );
  }
}
