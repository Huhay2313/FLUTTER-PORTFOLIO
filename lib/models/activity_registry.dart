import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/activity1_screen.dart';
import '../screens/activity2_screen.dart';
import 'activity_meta.dart';

// Single registry file for all lab activities across the semester.
// This is the ONLY file touched when a new lab activity is added.
final List<ActivityMeta> labActivities = [
  ActivityMeta(
    id: 'activity_1',
    title: 'Activity 1',
    subtitle: 'Notes & Ideas • Quick personal notebook',
    icon: Icons.sticky_note_2_rounded,
    color: AppPalette.primary,
    colorSoft: AppPalette.primarySoft,
    builder: (context) => const Activity1Screen(),
  ),
  ActivityMeta(
    id: 'activity_2',
    title: 'Activity 2',
    subtitle: 'Task Checklist • Daily activity tracker',
    icon: Icons.checklist_rounded,
    color: AppPalette.accent,
    colorSoft: AppPalette.accentSoft,
    builder: (context) => const Activity2Screen(),
  ),
];
