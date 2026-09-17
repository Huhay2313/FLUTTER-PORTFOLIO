import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/checklist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/checklist_tile.dart';
import '../widgets/motion.dart';

// Activity2Screen — StatefulWidget managing checklist with borderless input,
// hairline dividers, animated completion states, and pull-to-refresh.
class Activity2Screen extends StatefulWidget {
  const Activity2Screen({super.key});

  @override
  State<Activity2Screen> createState() => _Activity2ScreenState();
}

class _Activity2ScreenState extends State<Activity2Screen> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChecklistProvider>().loadItems();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final label = _ctrl.text.trim();
    if (label.isEmpty) return;
    HapticFeedback.lightImpact();
    await context.read<ChecklistProvider>().addItem(label);
    _ctrl.clear();
    if (mounted) {
      showAppSnackbar(context,
          message: 'Task added', icon: Icons.check_circle_rounded);
    }
  }

  void _deleteItem(int id) {
    HapticFeedback.lightImpact();
    context.read<ChecklistProvider>().deleteItem(id);
    showAppSnackbar(context,
        message: 'Task deleted',
        icon: Icons.delete_outline_rounded,
        isDestructive: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChecklistProvider>();
    final items = provider.items;
    final done = provider.doneCount;
    final progress = items.isEmpty ? 0.0 : done / items.length;

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Activity 1.5 — Checklist',
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
        onRefresh: () => context.read<ChecklistProvider>().loadItems(),
        child: Column(
          children: [
            // ── Single Brand Gradient Hero Banner ─────────────────────
            Padding(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DAILY PROGRESS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.white70,
                          ),
                        ),
                        // Tinted accent badge for highlights
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$done / ${items.length}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      items.isEmpty
                          ? 'No tasks registered yet'
                          : '${(progress * 100).toInt()}% completed',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Priority 2: Borderless input directly on background ────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add a new task...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppPalette.textSecondary(context),
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filled tinted icon button (accentSoft background)
                  TapScale(
                    onTap: _addItem,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppPalette.accentSoft,
                        borderRadius: BorderRadius.circular(44 * 0.32),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppPalette.accent,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hairline separator below input
            Divider(
              height: 1,
              thickness: 0.8,
              indent: 16,
              endIndent: 16,
              color: AppPalette.textSecondary(context).withValues(alpha: 0.12),
            ),

            // ── Priority 2: ListView.separated + hairline Divider ─────
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppPalette.accentSoft,
                                borderRadius: BorderRadius.circular(80 * 0.32),
                              ),
                              child: const Icon(
                                Icons.checklist_rounded,
                                size: 40,
                                color: AppPalette.accent,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'All caught up!',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add a new task above to stay on track.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppPalette.textSecondary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.8,
                        indent: 72,
                        endIndent: 16,
                        color: AppPalette.textSecondary(context)
                            .withValues(alpha: 0.12),
                      ),
                      itemBuilder: (context, i) => FadeSlideEntrance(
                        index: i,
                        child: ChecklistTile(
                          item: items[i],
                          onToggle: () => context
                              .read<ChecklistProvider>()
                              .toggle(items[i]),
                          onDelete: () => _deleteItem(items[i].id!),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
