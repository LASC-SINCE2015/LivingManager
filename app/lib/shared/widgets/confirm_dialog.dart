import 'package:flutter/material.dart';

/// 確認ダイアログを出し、OK が押されたら true を返す
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  required String okLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(okLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
