import 'dart:convert';

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

  factory Memo.create({required String content}) {
    final now = DateTime.now();
    return Memo(
      id: now.millisecondsSinceEpoch.toString(),
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

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
    id: json['id'],
    content: json['content'],
    isFavorite: json['isFavorite'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  static String encodeList(List<Memo> memos) =>
      jsonEncode(memos.map((m) => m.toJson()).toList());

  static List<Memo> decodeList(String source) =>
      (jsonDecode(source) as List).map((e) => Memo.fromJson(e)).toList();
}
