import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/features/items/presentation/items_page.dart';

void main() {
  testWidgets('在庫一覧画面にタイトルが表示される', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ItemsPage()));

    expect(find.text('在庫一覧'), findsOneWidget);
  });
}
