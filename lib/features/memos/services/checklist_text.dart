// Checklist lines live inside Memo.content. The stored shape stays a plain string:
// U+2610 + space is an open item, U+2611 + space is a done item. No new JSON key.

class ChecklistProgress {
  const ChecklistProgress({required this.done, required this.total});

  final int done;
  final int total;
}

class ChecklistSelectionEdit {
  const ChecklistSelectionEdit({
    required this.text,
    required this.base,
    required this.extent,
  });

  final String text;
  final int base;
  final int extent;
}

class ChecklistNewlineEdit {
  const ChecklistNewlineEdit({required this.text, required this.cursor});

  final String text;
  final int cursor;
}

class ChecklistText {
  ChecklistText._();

  static const String uncheckedMark = '\u2610';
  static const String checkedMark = '\u2611';
  static const String unchecked = '$uncheckedMark ';
  static const String checked = '$checkedMark ';

  static bool hasPrefix(String line) =>
      line.startsWith(unchecked) || line.startsWith(checked);

  static bool isEmptyItem(String line) => line == unchecked || line == checked;

  static ChecklistProgress? progressOf(String content) {
    var done = 0;
    var total = 0;
    for (final line in content.split('\n')) {
      if (line.startsWith(checked)) {
        done += 1;
        total += 1;
      } else if (line.startsWith(unchecked)) {
        total += 1;
      }
    }
    if (total == 0) return null;
    return ChecklistProgress(done: done, total: total);
  }

  /// Same trailing-whitespace cleanup the editor already applied, plus the
  /// single prefix space on an otherwise empty checklist line.
  static String normalizeStoredContent(String raw) {
    final lines = raw.split('\n').map((line) {
      final trimmed = line.trimRight();
      if (trimmed == uncheckedMark || trimmed == checkedMark) {
        return '$trimmed ';
      }
      return trimmed;
    });
    final result = lines.join('\n').trim();
    if (result == uncheckedMark ||
        result == checkedMark ||
        result.endsWith('\n$uncheckedMark') ||
        result.endsWith('\n$checkedMark')) {
      return '$result ';
    }
    return result;
  }

  static String? toggleCheckedAt(String text, int offset) {
    if (offset < 0 || offset >= text.length) return null;
    final line = _lineAt(text, offset);
    if (line.start != offset) return null;
    final lineText = text.substring(line.start, line.contentEnd);
    if (lineText.startsWith(unchecked)) {
      return text.replaceRange(offset, offset + 1, checkedMark);
    }
    if (lineText.startsWith(checked)) {
      return text.replaceRange(offset, offset + 1, uncheckedMark);
    }
    return null;
  }

  static ChecklistSelectionEdit togglePrefixes({
    required String text,
    required int base,
    required int extent,
    required bool selectionValid,
  }) {
    final selBase = selectionValid ? base.clamp(0, text.length) : 0;
    final selExtent = selectionValid ? extent.clamp(0, text.length) : 0;
    final start = selBase < selExtent ? selBase : selExtent;
    final end = selBase < selExtent ? selExtent : selBase;
    final lines = _lineSpans(text);
    final include = <int>{};
    if (start == end) {
      include.add(_lineIndexAt(lines, start));
    } else {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineExtent = line.newline == null
            ? line.contentEnd
            : line.newline! + 1;
        if (start < lineExtent && end > line.start) include.add(i);
      }
      if (include.isEmpty) include.add(_lineIndexAt(lines, start));
    }

    final map = List<int>.filled(text.length + 1, 0);
    final out = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineText = text.substring(line.start, line.contentEnd);
      if (!include.contains(i)) {
        for (var c = line.start; c < line.contentEnd; c++) {
          map[c] = out.length;
          out.write(text[c]);
        }
      } else if (hasPrefix(lineText)) {
        map[line.start] = out.length;
        if (line.contentEnd > line.start) map[line.start + 1] = out.length;
        for (var c = line.start + 2; c < line.contentEnd; c++) {
          map[c] = out.length;
          out.write(text[c]);
        }
      } else {
        out.write(unchecked);
        for (var c = line.start; c < line.contentEnd; c++) {
          map[c] = out.length;
          out.write(text[c]);
        }
        if (line.contentEnd == line.start) map[line.start] = out.length;
      }
      if (line.newline != null) {
        map[line.newline!] = out.length;
        out.write('\n');
      }
    }
    map[text.length] = out.length;

    return ChecklistSelectionEdit(
      text: out.toString(),
      base: map[selBase],
      extent: map[selExtent],
    );
  }

  /// A single newline inserted at a collapsed caret. Null means keep the edit.
  static ChecklistNewlineEdit? adjustNewline({
    required String oldText,
    required int oldCursor,
    required bool oldCollapsed,
    required String newText,
  }) {
    if (!oldCollapsed) return null;
    if (oldCursor < 0 || oldCursor > oldText.length) return null;
    if (newText.length != oldText.length + 1) return null;
    if (newText.substring(0, oldCursor) != oldText.substring(0, oldCursor)) {
      return null;
    }
    if (newText.codeUnitAt(oldCursor) != 0x0A) return null;
    if (newText.substring(oldCursor + 1) != oldText.substring(oldCursor)) {
      return null;
    }

    final line = _lineAt(oldText, oldCursor);
    final lineText = oldText.substring(line.start, line.contentEnd);
    if (!hasPrefix(lineText)) return null;

    if (isEmptyItem(lineText)) {
      final next = oldText.replaceRange(line.start, line.contentEnd, '');
      return ChecklistNewlineEdit(text: next, cursor: line.start);
    }

    final insertAt = oldCursor + 1;
    final rest = newText.substring(insertAt);
    if (rest.startsWith(unchecked) || rest.startsWith(checked)) return null;
    final next = newText.replaceRange(insertAt, insertAt, unchecked);
    return ChecklistNewlineEdit(
      text: next,
      cursor: insertAt + unchecked.length,
    );
  }

  static List<_Line> _lineSpans(String text) {
    final lines = <_Line>[];
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        lines.add(_Line(start: start, contentEnd: i, newline: i));
        start = i + 1;
      }
    }
    lines.add(_Line(start: start, contentEnd: text.length));
    return lines;
  }

  static _Line _lineAt(String text, int caret) {
    final lines = _lineSpans(text);
    return lines[_lineIndexAt(lines, caret)];
  }

  static int _lineIndexAt(List<_Line> lines, int caret) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (caret >= line.start && caret <= line.caretEnd) return i;
    }
    return lines.length - 1;
  }
}

class _Line {
  const _Line({required this.start, required this.contentEnd, this.newline});

  final int start;
  final int contentEnd;
  final int? newline;

  int get caretEnd => newline ?? contentEnd;
}
