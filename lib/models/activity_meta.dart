import 'package:flutter/material.dart';

// ActivityMeta model for dynamic registry in the master compilation app
class ActivityMeta {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color colorSoft;
  final WidgetBuilder builder;

  const ActivityMeta({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.colorSoft,
    required this.builder,
  });
}
