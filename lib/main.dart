import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/checklist_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

// Entry point — MultiProvider wraps the entire app so any descendant widget
// can access providers without boilerplate.
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
      ],
      child: const LabHubApp(),
    ),
  );
}

// LabHubApp — StatelessWidget; Consumer<ThemeProvider> scopes the rebuild
// to just MaterialApp when dark/light mode toggles.
class LabHubApp extends StatelessWidget {
  const LabHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeP, child) => MaterialApp(
        title: 'LabHub',
        debugShowCheckedModeBanner: false,
        themeMode: themeP.themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
