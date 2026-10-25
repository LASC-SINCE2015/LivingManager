import 'package:flutter/material.dart';

/// 画面下部に短いメッセージを表示する
void showMessage(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 保存処理を実行し、失敗したらエラーメッセージを表示する。
/// 成功したら結果を、失敗したら null を返す。
Future<T?> runWithErrorMessage<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await action();
  } catch (_) {
    showMessage(messenger, '保存できませんでした。通信状態を確認してください');
    return null;
  }
}
