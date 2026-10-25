import 'package:flutter/material.dart';

import '../domain/stock_status.dart';

/// ステータスごとの表示色
extension StockStatusColors on StockStatus {
  /// 基本の色（十分=緑・残りわずか=黄・切れてる=赤）
  Color get color => switch (this) {
    StockStatus.sufficient => Colors.green,
    StockStatus.low => Colors.amber,
    StockStatus.empty => Colors.red,
  };

  /// 薄い背景の上に置く文字色
  Color get onLightColor => switch (this) {
    StockStatus.sufficient => Colors.green.shade900,
    StockStatus.low => Colors.amber.shade900,
    StockStatus.empty => Colors.red.shade900,
  };
}
