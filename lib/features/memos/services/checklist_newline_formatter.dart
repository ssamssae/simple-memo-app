import 'package:flutter/services.dart';

import 'checklist_text.dart';

/// Enter on iOS and Android arrives as one inserted newline from the IME.
class ChecklistNewlineFormatter extends TextInputFormatter {
  const ChecklistNewlineFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selection = oldValue.selection;
    final edit = ChecklistText.adjustNewline(
      oldText: oldValue.text,
      oldCursor: selection.isValid ? selection.baseOffset : -1,
      oldCollapsed: selection.isValid && selection.isCollapsed,
      newText: newValue.text,
    );
    if (edit == null) return newValue;
    return TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
      composing: TextRange.empty,
    );
  }
}
