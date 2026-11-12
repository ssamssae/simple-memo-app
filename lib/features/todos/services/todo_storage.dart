import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo.dart';

class TodoLoad {
  const TodoLoad(this.todos, {required this.corrupt});

  final List<Todo> todos;

  /// 저장값이 있는데 읽지 못함. 화면은 이때 저장(덮어쓰기)을 하지 않는다.
  final bool corrupt;
}

class TodoStorage {
  TodoStorage._();

  static const key = 'todos';

  static Future<TodoLoad> load({bool throwOnError = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) {
      return const TodoLoad([], corrupt: false);
    }
    try {
      return TodoLoad(Todo.decodeList(data), corrupt: false);
    } on FormatException {
      if (throwOnError) rethrow;
      return const TodoLoad([], corrupt: true);
    } catch (e) {
      if (throwOnError) throw FormatException('Invalid todo list: $e');
      return const TodoLoad([], corrupt: true);
    }
  }

  static Future<bool> save(List<Todo> todos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(key, Todo.encodeList(todos));
    } catch (e) {
      debugPrint('[TodoStorage.save] $e');
      return false;
    }
  }
}
