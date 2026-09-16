import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/note_tile.dart';

// Activity1Screen — StatefulWidget managing notes list with pull-to-refresh,
// hairline dividers, staggered entrance, and haptic feedback.
class Activity1Screen extends StatefulWidget {
  const Activity1Screen({super.key});

  @override
  State<Activity1Screen> createState() => _Activity1ScreenState();
}

class _Activity1ScreenState extends State<Activity1Screen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().loadNotes();
    });
  }

  void _showNoteSheet({Note? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(40 * 0.32),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: AppPalette.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      existing == null ? 'Add Note' : 'Edit Note',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppPalette.textPrimary(sheetCtx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Borderless input sitting directly on surface
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppPalette.textPrimary(sheetCtx),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Note title...',
                    hintStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: AppPalette.textSecondary(sheetCtx),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Divider(
                  height: 24,
                  thickness: 0.8,
                  color:
                      AppPalette.textSecondary(sheetCtx).withValues(alpha: 0.15),
                ),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppPalette.textPrimary(sheetCtx),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts or lab notes here...',
                    hintStyle: GoogleFonts.inter(
                      color: AppPalette.textSecondary(sheetCtx),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 24),
                TapScale(
                  onTap: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final provider = context.read<NotesProvider>();
                    if (existing == null) {
                      await provider.addNote(title, bodyCtrl.text.trim());
                      if (mounted) {
                        showAppSnackbar(context,
                            message: 'Note added successfully',
                            icon: Icons.check_circle_rounded);
                      }
                    } else {
                      await provider.updateNote(existing.copyWith(
                        title: title,
                        body: bodyCtrl.text.trim(),
                      ));
                      if (mounted) {
                        showAppSnackbar(context,
                            message: 'Note updated',
                            icon: Icons.check_circle_rounded);
                      }
                    }
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      existing == null ? 'Save Note' : 'Update Note',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _confirmDelete(int id) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppPalette.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Note?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary(context),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppPalette.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppPalette.textSecondary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              final provider = context.read<NotesProvider>();
              Navigator.pop(dialogCtx);
              provider.deleteNote(id);
              showAppSnackbar(context,
                  message: 'Note deleted',
                  icon: Icons.delete_outline_rounded,
                  isDestructive: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesProvider>().notes;

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Activity 1 — Notes',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppPalette.textPrimary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppPalette.primary,
        onRefresh: () => context.read<NotesProvider>().loadNotes(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Single Brand Gradient Hero Banner ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(52 * 0.32),
                        ),
                        child: const Icon(
                          Icons.sticky_note_2_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${notes.length} ${notes.length == 1 ? "Note" : "Notes"} Saved',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Private notes stored safely on device',
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
              ),
            ),

            // ── Empty State or ListView.separated ─────────────────────
            if (notes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppPalette.primarySoft,
                            borderRadius: BorderRadius.circular(80 * 0.32),
                          ),
                          child: const Icon(
                            Icons.note_alt_outlined,
                            size: 40,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No notes yet',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap "+ Add Note" below to jot your first idea.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppPalette.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final itemIndex = index ~/ 2;
                      if (index.isOdd) {
                        return Divider(
                          height: 1,
                          thickness: 0.8,
                          indent: 76,
                          endIndent: 16,
                          color: AppPalette.textSecondary(context)
                              .withValues(alpha: 0.12),
                        );
                      }
                      final note = notes[itemIndex];
                      return FadeSlideEntrance(
                        index: itemIndex,
                        child: NoteTile(
                          note: note,
                          onDelete: () => _confirmDelete(note.id!),
                          onEdit: () => _showNoteSheet(existing: note),
                        ),
                      );
                    },
                    childCount: notes.length * 2 - 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: TapScale(
        onTap: () {
          HapticFeedback.lightImpact();
          _showNoteSheet();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppPalette.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add Note',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
