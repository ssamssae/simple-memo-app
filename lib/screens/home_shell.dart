import 'package:flutter/material.dart';

import 'memo_list_screen.dart';
import 'settings_screen.dart';

/// 메모요 루트 셸 — 하단 바텀바(메모 / 새메모 / 설정).
///
/// 메모(0)와 설정(2)은 IndexedStack 으로 상태를 유지한 채 전환하는 탭이고,
/// 가운데 '새메모'(1)는 페이지가 아니라 새 메모 편집기를 여는 액션이라
/// 탭 인덱스를 바꾸지 않고 MemoListScreen 의 새 메모 작성을 호출한다.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // body 인덱스: 0=메모, 1=설정. (바텀바의 가운데 '새메모'는 탭이 아니라 액션)
  int _bodyIndex = 0;
  final GlobalKey<MemoListScreenState> _memoListKey =
      GlobalKey<MemoListScreenState>();

  static const Color _accent = Color(0xFF7C5CFF);
  static const Color _inactive = Color(0xFF6E6E76);
  static const Color _barBg = Color(0xFF141417);

  void _onBarTapped(int barIndex) {
    switch (barIndex) {
      case 0: // 메모
        // 설정 탭에서 백업 복원·휴지통 복구 등으로 메모가 바뀌었을 수 있어
        // 메모 탭으로 돌아올 때 재로드한다.
        if (_bodyIndex != 0) {
          setState(() => _bodyIndex = 0);
          _memoListKey.currentState?.reloadMemos();
        }
        break;
      case 1: // 새메모 (액션 — 탭 전환 X)
        _memoListKey.currentState?.startNewMemo();
        break;
      case 2: // 설정
        if (_bodyIndex != 1) setState(() => _bodyIndex = 1);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 바텀바 하이라이트는 메모(0)/설정(2)만. 새메모(1)는 항상 비활성 톤.
    final barCurrent = _bodyIndex == 0 ? 0 : 2;
    return Scaffold(
      body: IndexedStack(
        index: _bodyIndex,
        children: [
          MemoListScreen(key: _memoListKey),
          const SettingsScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: barCurrent,
        onTap: _onBarTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: _barBg,
        selectedItemColor: _accent,
        unselectedItemColor: _inactive,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sticky_note_2_outlined),
            activeIcon: Icon(Icons.sticky_note_2),
            label: '메모',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: '새메모',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
