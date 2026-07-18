// T-260718-045 스파이크 — MemoStorage 의 앱인토스 Storage 어댑터.
//
// 검증 (c) 항: shared_preferences(문자열 JSON) → 앱인토스 Storage(문자열 API) 브릿지가
// 코드 구조상 성립하는지 실증한다. 본편 MemoStorage 와 같은 키·같은 인코딩
// (Memo.encodeList/decodeList)을 쓰므로, 어댑터 교체만으로 CRUD 레이어가 이식된다.
// 토스 러닝타임 밖에서는 shared_preferences(웹=localStorage)로 폴백한다.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/memo.dart';
import 'ait_bridge.dart';

class AitMemoStore {
  static const _key = 'memos';

  /// 실제로 어느 백엔드를 썼는지 (진단 표시용): 'ait-storage' | 'shared-preferences'
  static String lastBackend = 'unknown';

  static Future<List<Memo>> loadMemos() async {
    try {
      if (AitBridge.sdkAvailable) {
        lastBackend = 'ait-storage';
        final data = await AitBridge.storageGet(_key);
        if (data == null || data.isEmpty) return [];
        return Memo.decodeList(data);
      }
      lastBackend = 'shared-preferences';
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null || data.isEmpty) return [];
      return Memo.decodeList(data);
    } catch (e) {
      debugPrint('[AitMemoStore.loadMemos] $e');
      return [];
    }
  }

  static Future<void> saveMemos(List<Memo> memos) async {
    try {
      final encoded = Memo.encodeList(memos);
      if (AitBridge.sdkAvailable) {
        lastBackend = 'ait-storage';
        await AitBridge.storageSet(_key, encoded);
        return;
      }
      lastBackend = 'shared-preferences';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, encoded);
    } catch (e) {
      debugPrint('[AitMemoStore.saveMemos] $e');
    }
  }
}
