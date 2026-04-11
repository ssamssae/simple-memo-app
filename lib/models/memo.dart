import 'dart:convert';
import 'package:uuid/uuid.dart';

class Memo {
  final String id;
  String content;
  bool isFavorite;
  final DateTime createdAt;
  DateTime updatedAt;

  Memo({
    required this.id,
    required this.content,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get firstLine {
    final line = content.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '새 메모',
    );
    return line.trim();
  }

  // copyWith: 불변 방식으로 필드 변경
  Memo copyWith({
    String? content,
    bool? isFavorite,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id,
      content: content ?? this.content,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _uuid = Uuid();

  factory Memo.create({required String content}) {
    final now = DateTime.now();
    return Memo(
      id: _uuid.v4(),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Memo.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Memo(
      id: json['id'] as String? ?? now.millisecondsSinceEpoch.toString(),
      content: json['content'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
    );
  }

  static String encodeList(List<Memo> memos) =>
      jsonEncode(memos.map((m) => m.toJson()).toList());

  static List<Memo> decodeList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => Memo.fromJson(e))
        .toList();
  }
}
