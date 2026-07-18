// T-260718-045 앱인토스 웹 래퍼 스파이크 전용 엔트리포인트.
//
// 본편 main.dart 와 완전 분리 — 광고·IAP·Drive·흔들기·프리미엄은 import 그래프에서
// 제외된다(웹 미지원 플러그인 컴파일 배제). 핵심 CRUD(작성·목록·수정·삭제)만
// 실제 Memo 모델 + AitMemoStore(앱인토스 Storage 어댑터, 폴백=localStorage) 위에서 돈다.
//
// 빌드: flutter build web --target=lib/main_ait_spike.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ait/ait_bridge.dart';
import 'ait/ait_memo_store.dart';
import 'models/memo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AitSpikeApp());
}

class AitSpikeApp extends StatelessWidget {
  const AitSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모요 AIT 스파이크',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4A90D9), useMaterial3: true),
      home: const SpikeMemoScreen(),
    );
  }
}

class SpikeMemoScreen extends StatefulWidget {
  const SpikeMemoScreen({super.key});

  @override
  State<SpikeMemoScreen> createState() => _SpikeMemoScreenState();
}

class _SpikeMemoScreenState extends State<SpikeMemoScreen> {
  List<Memo> _memos = [];
  bool _loading = true;
  String _diag = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final memos = await AitMemoStore.loadMemos();
    final os = await AitBridge.platformOS();
    setState(() {
      _memos = memos.where((m) => m.deletedAt == null).toList();
      _loading = false;
      _diag = 'glue=${AitBridge.glueLoaded} sdk=${AitBridge.sdkAvailable} '
          'os=${os ?? '-'} store=${AitMemoStore.lastBackend} '
          'insets=${AitBridge.safeAreaInsets ?? '-'}';
    });
  }

  Future<void> _save() async {
    await AitMemoStore.saveMemos(_memos);
    setState(() {
      _diag = 'saved via ${AitMemoStore.lastBackend} @${DateTime.now().toIso8601String().substring(11, 19)}';
    });
  }

  Future<void> _edit([Memo? memo]) async {
    final controller = TextEditingController(text: memo?.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(memo == null ? '새 메모' : '메모 수정'),
        content: TextField(controller: controller, autofocus: true, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('저장')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final now = DateTime.now();
    setState(() {
      if (memo == null) {
        _memos.insert(
          0,
          Memo(id: const Uuid().v4(), content: result.trim(), createdAt: now, updatedAt: now),
        );
      } else {
        memo
          ..content = result.trim()
          ..updatedAt = now;
      }
    });
    await _save();
  }

  Future<void> _delete(Memo memo) async {
    setState(() => _memos.remove(memo));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    // 검증 (b): 루트에서 뒤로가기 → 앱인토스 closeView (SDK 밖에서는 no-op).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AitBridge.closeView();
      },
      // 검증 (d): SafeArea — 토스 WebView 의 inset 반영 확인용으로 진단 바에 값 표시.
      child: Scaffold(
        appBar: AppBar(title: const Text('메모요 스파이크 (CRUD)')),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0x114A90D9),
                padding: const EdgeInsets.all(6),
                child: Text(_diag, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _memos.isEmpty
                        ? const Center(child: Text('메모가 없어요. + 로 추가하세요.'))
                        : ListView.separated(
                            itemCount: _memos.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final m = _memos[i];
                              return ListTile(
                                title: Text(m.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _edit(m),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(m),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _edit(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
