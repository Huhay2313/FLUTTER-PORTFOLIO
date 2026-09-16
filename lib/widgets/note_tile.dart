import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

// NoteTile — StatelessWidget (pure render, no internal state).
// Sits directly on the background in ListView.separated with hairline Divider (no boxed container).
class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const NoteTile({
    super.key,
    required this.note,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(note.createdAt);
    final dateStr = dt != null
        ? '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    const double iconChipSize = 44.0;
    const double iconChipRadius = iconChipSize * 0.32;
    const double actionChipSize = 34.0;
    const double actionChipRadius = actionChipSize * 0.32;

    return Padding(
      // 8pt grid: 16 horizontal, 12 vertical
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tinted squircle note icon chip
          Container(
            width: iconChipSize,
            height: iconChipSize,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(iconChipRadius),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppPalette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Note details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppPalette.textPrimary(context),
                  ),
                ),
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppPalette.textSecondary(context),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons with micro-interaction
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TapScale(
                onTap: onEdit,
                child: Container(
                  width: actionChipSize,
                  height: actionChipSize,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(actionChipRadius),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppPalette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TapScale(
                onTap: onDelete,
                child: Container(
                  width: actionChipSize,
                  height: actionChipSize,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(actionChipRadius),
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
        ],
      ),
    );
  }
}
