// Model for Activity 2 — Checklist items
// Plain Dart class; SQLite-ready with toMap/fromMap helpers
class ChecklistItem {
  final int? id;
  final String label;
  final bool isDone;
  final String createdAt;

  const ChecklistItem({
    this.id,
    required this.label,
    required this.isDone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'is_done': isDone ? 1 : 0, // SQLite stores booleans as integers
        'created_at': createdAt,
      };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as int?,
        label: map['label'] as String,
        isDone: (map['is_done'] as int) == 1,
        createdAt: map['created_at'] as String,
      );

  ChecklistItem copyWith({
    int? id,
    String? label,
    bool? isDone,
    String? createdAt,
  }) =>
      ChecklistItem(
        id: id ?? this.id,
        label: label ?? this.label,
        isDone: isDone ?? this.isDone,
        createdAt: createdAt ?? this.createdAt,
      );
}
