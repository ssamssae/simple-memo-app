import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../l10n/app_strings.dart';


/// 인앱 정책 표시 화면 — assets/legal/*.md 를 읽어 간단히 렌더한다.
/// 외부 패키지 없이 메모앱 수준의 경량 마크다운 부분집합만 처리
/// (#/##/### 헤딩, `- ` 불릿, `> ` 안내, `| | ` 표, `**강조**`).
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(fontSize: 17)),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(assetPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text(AppStrings.of(context).docLoadFailed));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: _render(context, snapshot.data!),
            );
          },
        ),
      ),
    );
  }

  // ── 경량 마크다운 → 위젯 ──────────────────────────────
  List<Widget> _render(BuildContext context, String md) {
    final base = Theme.of(context).textTheme;
    final widgets = <Widget>[];

    for (final raw in md.split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      // 표 구분선(|---|---|) skip
      if (_isTableSeparator(trimmed)) continue;

      // 헤딩
      if (trimmed.startsWith('### ')) {
        widgets.add(_block(_clean(trimmed.substring(4)),
            base.titleSmall?.copyWith(fontWeight: FontWeight.w600), 14, 6));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(_block(_clean(trimmed.substring(3)),
            base.titleMedium?.copyWith(fontWeight: FontWeight.bold), 16, 6));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(_block(_clean(trimmed.substring(2)),
            base.titleLarge?.copyWith(fontWeight: FontWeight.bold), 8, 8));
      } else if (trimmed.startsWith('> ')) {
        // 안내(blockquote)
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_clean(trimmed.substring(2)),
              style: base.bodySmall?.copyWith(color: Colors.white70)),
        ));
      } else if (trimmed.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Text('•  ${_clean(trimmed.substring(2))}',
              style: base.bodyMedium),
        ));
      } else if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        // 표 행 → 셀을 ' · ' 로 묶어 한 줄
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .map(_clean)
            .toList();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(cells.join('  ·  '), style: base.bodyMedium),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(_clean(trimmed), style: base.bodyMedium),
        ));
      }
    }
    return widgets;
  }

  Widget _block(String text, TextStyle? style, double top, double bottom) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Text(text, style: style),
    );
  }

  bool _isTableSeparator(String s) {
    if (!s.startsWith('|')) return false;
    return RegExp(r'^\|[\s:\-\|]+\|$').hasMatch(s);
  }

  // 강조/코드 마커 제거(인라인 굵게는 단순화하여 평문 렌더)
  String _clean(String s) =>
      s.replaceAll('**', '').replaceAll('`', '').trim();
}
