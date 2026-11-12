import 'dart:convert';

import 'package:uuid/uuid.dart';

/// 할 일 한 개(T-261112-052). 메모(Memo)와 따로 `todos` 키에 저장한다.
/// 순서는 따로 필드를 두지 않고 저장 배열 순서를 쓴다.
class Todo {
  const Todo({
    required this.id,
    required this.title,
    this.note = '',
    this.done = false,
    this.doneAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String note;
  final bool done;
  final DateTime? doneAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasNote => note.trim().isNotEmpty;

  static const _uuid = Uuid();

  factory Todo.create({
    required String title,
    String note = '',
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    return Todo(
      id: _uuid.v4(),
      title: title.trim(),
      note: note,
      createdAt: t,
      updatedAt: t,
    );
  }

  Todo copyWith({
    String? title,
    String? note,
    bool? done,
    DateTime? doneAt,
    bool clearDoneAt = false,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      done: done ?? this.done,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (note.isNotEmpty) 'note': note,
    'done': done,
    if (doneAt != null) 'doneAt': doneAt!.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Todo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final created = json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt'] as String)
        : null;
    final updated = json['updatedAt'] is String
        ? DateTime.tryParse(json['updatedAt'] as String)
        : null;
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        created == null ||
        updated == null) {
      throw const FormatException('Invalid todo');
    }
    final note = json['note'];
    final doneAt = json['doneAt'];
    return Todo(
      id: id,
      title: title,
      note: note is String ? note : '',
      done: json['done'] == true,
      doneAt: doneAt is String ? DateTime.tryParse(doneAt) : null,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static List<Todo> decodeList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List ||
        decoded.any((row) => row is! Map<String, dynamic>)) {
      throw const FormatException('Invalid todo list');
    }
    return decoded.cast<Map<String, dynamic>>().map(Todo.fromJson).toList();
  }

  static String encodeList(List<Todo> todos) =>
      jsonEncode(todos.map((t) => t.toJson()).toList());
}
