import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';


class Memo {
  // 휴지통 보관 기간 — 이 기간 지난 soft-deleted 메모는 영구 삭제(purge).
  // timeUntilPurge / MemoStorage.purgeExpiredTrash 의 단일 기준값.
  static const trashRetention = Duration(days: 30);

  final String id;
  String content;
  bool isFavorite;
  final DateTime createdAt;
  DateTime updatedAt;
  // null = 활성 메모, 값 있음 = 휴지통(soft-deleted)에 들어간 시각.
  DateTime? deletedAt;
  final List<double>? semanticEmbedding;
  final String? semanticEmbeddingModel;
  final String? semanticEmbeddingSource;
  // 첨부 사진 파일명 목록 (경로 없음, <앱문서>/attachments/ 아래). 순서 = 표시 순서.
  // 1.0.18 이하 JSON 엔 키가 없고 → 빈 목록. 상한(10장)은 모델이 아니라
  // AttachmentService 가 강제한다 — 백업 복원 등 외부 유입 값은 자르지 않는다.
  final List<String> imageFiles;

  Memo({
    required this.id,
    required this.content,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    List<double>? semanticEmbedding,
    this.semanticEmbeddingModel,
    this.semanticEmbeddingSource,
    List<String>? imageFiles,
  }) : semanticEmbedding = semanticEmbedding == null
           ? null
           : List<double>.unmodifiable(semanticEmbedding),
       imageFiles = List<String>.unmodifiable(imageFiles ?? const <String>[]);

  String get firstLine {
    final line = content
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => AppStrings.fromCode(SettingsService.instance.languageCode.value).untitledMemo);
    return line.trim();
  }

  String get title => firstLine;

  bool get isInTrash => deletedAt != null;

  bool get hasImages => imageFiles.isNotEmpty;

  // 파일명 = uuid.jpg 형태만. 경로 구분자·`..`·선행 점을 막아 JSON(백업 복원 포함)에서
  // 들어온 값이 attachments/ 밖을 가리킬 수 없게 한다.
  // `..` 검사는 이중 방어 — 현재 regex 가 `/`·`\` 를 막아 traversal 은 불가하지만,
  // 문자 클래스를 넓히는 미래 변경에 대비해 남겨 둔다.
  static final _imageFileNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
  static bool isValidImageFileName(String name) =>
      !name.contains('..') && _imageFileNamePattern.hasMatch(name);

  // 영구삭제까지 남은 시간. 활성 메모(deletedAt == null)는 Duration.zero.
  // 이미 기간 지났으면 음수 Duration(= purge 대상).
  Duration get timeUntilPurge {
    final d = deletedAt;
    if (d == null) return Duration.zero;
    return d.add(trashRetention).difference(DateTime.now());
  }

  // deletedAt 의 "미지정(기존값 유지)" 과 "명시적 null(휴지통에서 복구)" 을
  // 구분하기 위한 sentinel. content/isFavorite/updatedAt 은 기존 동작 유지.
  static const _undefinedDeletedAt = Object();
  static const _undefinedSemanticEmbedding = Object();
  static const _undefinedSemanticEmbeddingModel = Object();
  static const _undefinedSemanticEmbeddingSource = Object();

  // copyWith: 불변 방식으로 필드 변경
  Memo copyWith({
    String? content,
    bool? isFavorite,
    DateTime? updatedAt,
    Object? deletedAt = _undefinedDeletedAt,
    Object? semanticEmbedding = _undefinedSemanticEmbedding,
    Object? semanticEmbeddingModel = _undefinedSemanticEmbeddingModel,
    Object? semanticEmbeddingSource = _undefinedSemanticEmbeddingSource,
    List<String>? imageFiles,
  }) {
    return Memo(
      id: id,
      content: content ?? this.content,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _undefinedDeletedAt)
          ? this.deletedAt
          : deletedAt as DateTime?,
      semanticEmbedding:
          identical(semanticEmbedding, _undefinedSemanticEmbedding)
          ? this.semanticEmbedding
          : _parseEmbedding(semanticEmbedding),
      semanticEmbeddingModel:
          identical(semanticEmbeddingModel, _undefinedSemanticEmbeddingModel)
          ? this.semanticEmbeddingModel
          : semanticEmbeddingModel as String?,
      semanticEmbeddingSource:
          identical(semanticEmbeddingSource, _undefinedSemanticEmbeddingSource)
          ? this.semanticEmbeddingSource
          : semanticEmbeddingSource as String?,
      imageFiles: imageFiles ?? this.imageFiles,
    );
  }

  static const _uuid = Uuid();

  factory Memo.create({required String content, List<String>? imageFiles}) {
    final now = DateTime.now();
    return Memo(
      id: _uuid.v4(),
      content: content,
      createdAt: now,
      updatedAt: now,
      imageFiles: imageFiles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    // 활성 메모는 키 자체를 안 박음 — 1.0.6 이하 JSON 과 동일(백워드 호환).
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    if (semanticEmbedding != null) 'semanticEmbedding': semanticEmbedding,
    if (semanticEmbeddingModel != null)
      'semanticEmbeddingModel': semanticEmbeddingModel,
    if (semanticEmbeddingSource != null)
      'semanticEmbeddingSource': semanticEmbeddingSource,
    // 사진 없는 메모는 키 자체를 안 박음 — 1.0.18 이하 JSON 과 동일(백워드 호환).
    if (imageFiles.isNotEmpty) 'images': imageFiles,
  };

  factory Memo.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Memo(
      id: json['id'] as String? ?? now.millisecondsSinceEpoch.toString(),
      content: json['content'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
      // deletedAt 키 없으면(1.0.6 이하·활성) null. 파싱 실패도 null(활성 취급, 안전).
      deletedAt: DateTime.tryParse(json['deletedAt'] ?? ''),
      semanticEmbedding: _parseEmbedding(json['semanticEmbedding']),
      semanticEmbeddingModel: json['semanticEmbeddingModel'] as String?,
      semanticEmbeddingSource: json['semanticEmbeddingSource'] as String?,
      imageFiles: _parseImageFiles(json['images']),
    );
  }

  static List<double>? _parseEmbedding(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final values = <double>[];
    for (final value in raw) {
      if (value is! num || !value.isFinite) return null;
      values.add(value.toDouble());
    }
    return values;
  }

  static List<String> _parseImageFiles(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is String && isValidImageFileName(value)) value,
    ];
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
