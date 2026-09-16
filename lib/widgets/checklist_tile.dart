import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/checklist_item.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

// ChecklistTile — StatelessWidget with animated strike-through and fade.
// Sits directly on the background in ListView.separated with hairline Divider (no boxed container).
class ChecklistTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ChecklistTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const double chipSize = 40.0;
    const double chipRadius = chipSize * 0.32;
    const double deleteSize = 34.0;
    const double deleteRadius = deleteSize * 0.32;

    return Padding(
      // 8pt grid: 16 horizontal, 10 vertical
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AnimatedOpacity(
        opacity: item.isDone ? 0.45 : 1.0,
        duration: const Duration(milliseconds: 240),
        child: Row(
          children: [
            // Squircle checkbox toggle chip
            TapScale(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggle();
              },
              scaleDown: 0.90,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: chipSize,
                height: chipSize,
                decoration: BoxDecoration(
                  color: item.isDone
                      ? AppPalette.accent
                      : AppPalette.accentSoft,
                  borderRadius: BorderRadius.circular(chipRadius),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      item.isDone ? Icons.check_rounded : Icons.circle_outlined,
                      key: ValueKey(item.isDone),
                      size: 20,
                      color: item.isDone ? Colors.white : AppPalette.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Task label with animated strikethrough transition
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: item.isDone
                      ? AppPalette.textSecondary(context)
                      : AppPalette.textPrimary(context),
                  decoration: item.isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: AppPalette.textSecondary(context),
                  decorationThickness: 1.8,
                ),
                child: Text(item.label),
              ),
            ),
            const SizedBox(width: 8),
            // Delete squircle chip with haptic feedback
            TapScale(
              onTap: () {
                HapticFeedback.lightImpact();
                onDelete();
              },
              child: Container(
                width: deleteSize,
                height: deleteSize,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(deleteRadius),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
