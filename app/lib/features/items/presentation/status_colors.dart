import 'package:flutter/material.dart';

import '../domain/stock_status.dart';

/// ステータスごとの表示色・アイコン
extension StockStatusColors on StockStatus {
  /// 基本の色（十分=緑・残りわずか=黄・切れてる=赤）
  Color get color => switch (this) {
    StockStatus.sufficient => const Color(0xFF3FA27A),
    StockStatus.low => const Color(0xFFF2A93B),
    StockStatus.empty => const Color(0xFFE5585B),
  };

  /// 薄い背景の上に置く文字色
  Color get onLightColor => switch (this) {
    StockStatus.sufficient => const Color(0xFF1F5E44),
    StockStatus.low => const Color(0xFF8A5A00),
    StockStatus.empty => const Color(0xFF9E2427),
  };

  /// アイコン（色だけに頼らず、形でも見分けられるようにする）
  IconData get icon => switch (this) {
    StockStatus.sufficient => Icons.check_circle_rounded,
    StockStatus.low => Icons.hourglass_bottom_rounded,
    StockStatus.empty => Icons.cancel_rounded,
  };
}
