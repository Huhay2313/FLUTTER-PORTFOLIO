import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_meta.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

// ActivityCard — StatelessWidget (reusable UI piece with no internal state).
// FoodPanda/Instagram-tier card with TapScale micro-interaction and squircle chip.
class ActivityCard extends StatelessWidget {
  final ActivityMeta activity;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double chipSize = 50.0;
    const double chipRadius = chipSize * 0.32;

    return Padding(
      // 8pt grid: 16 horizontal, 8 vertical
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TapScale(
        onTap: onTap,
        scaleDown: 0.975,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.surface(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppPalette.cardShadow(context),
          ),
          child: Row(
            children: [
              // Icon chip with 32% squircle radius
              Container(
                width: chipSize,
                height: chipSize,
                decoration: BoxDecoration(
                  color: activity.colorSoft,
                  borderRadius: BorderRadius.circular(chipRadius),
                ),
                child: Icon(
                  activity.icon,
                  color: activity.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Activity title & subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppPalette.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppPalette.textSecondary(context),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trailing chevron indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(32 * 0.32),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
