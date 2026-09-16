// Model for Activity 1 — Notes CRUD
// Plain Dart class; no Flutter dependency needed here (StatelessWidget-friendly)
class Note {
  final int? id;
  final String title;
  final String body;
  final String createdAt;

  const Note({
    this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  // Convert to map for SQLite insertion
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt,
      };

  // Reconstruct from SQLite row
  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        title: map['title'] as String,
        body: map['body'] as String,
        createdAt: map['created_at'] as String,
      );

  Note copyWith({int? id, String? title, String? body, String? createdAt}) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt ?? this.createdAt,
      );
}
