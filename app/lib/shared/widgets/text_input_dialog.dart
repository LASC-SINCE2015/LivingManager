import 'package:flutter/material.dart';

/// 1 行のテキストを入力するダイアログ。保存されたら前後の空白を除いた値を返す
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  int? maxLength,
  String? Function(String value)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      maxLength: maxLength,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.maxLength,
    required this.validator,
  });

  final String title;
  final String label;
  final String initialValue;
  final int? maxLength;
  final String? Function(String value)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          decoration: InputDecoration(labelText: widget.label),
          validator: (value) => widget.validator?.call((value ?? '').trim()),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
