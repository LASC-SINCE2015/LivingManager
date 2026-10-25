import 'package:flutter_test/flutter_test.dart';
import 'package:living_manager/core/utils/text_normalizer.dart';

void main() {
  group('normalizeForCompare', () {
    test('前後の空白（全角スペースを含む）を取り除く', () {
      expect(normalizeForCompare('　 洗剤 　'), '洗剤');
    });

    test('カタカナとひらがなを区別しない', () {
      expect(
        normalizeForCompare('トイレットペーパー'),
        normalizeForCompare('といれっとぺーぱー'),
      );
    });

    test('全角・半角と大文字・小文字を区別しない', () {
      expect(normalizeForCompare('ＡＢＣ１２３'), normalizeForCompare('abc123'));
    });

    test('違う名前は違う値になる', () {
      expect(
        normalizeForCompare('シャンプー'),
        isNot(normalizeForCompare('リンス')),
      );
    });
  });
}
