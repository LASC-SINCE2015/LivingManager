import 'package:flutter/material.dart';

/// 日用品の一覧画面（雛形。中身は feature_poc で実装する）
class ItemsPage extends StatelessWidget {
  const ItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('在庫一覧')),
      body: const Center(child: Text('ここに日用品の一覧を表示します')),
    );
  }
}
