import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/widgets/text_input_dialog.dart';
import '../domain/barcode.dart';

/// カメラでバーコードを読み取る画面を開き、読み取った値を返す
/// （`normalizeBarcode` でそろえた値。閉じたら null）。
///
/// カメラが使えないときのために、番号を手で入力することもできる。
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const BarcodeScannerPage(),
    ),
  );
}

/// バーコードの読み取り画面
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.itf14,
    ],
  );

  /// 読み取って画面を閉じたか（続けて検出されても 2 回閉じないため）
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      // 読み間違い（チェックデジットが合わない）は無視して、次の検出を待つ
      final code = normalizeBarcode(barcode.rawValue ?? '');
      if (code == null) continue;
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  Future<void> _enterManually() async {
    final input = await showTextInputDialog(
      context,
      title: 'バーコードの番号を入力',
      label: '番号（8・12・13・14 桁）',
      maxLength: 20,
      validator: (value) =>
          normalizeBarcode(value) == null ? '正しい番号を入力してください' : null,
    );
    if (input == null || !mounted || _done) return;
    _done = true;
    Navigator.of(context).pop(normalizeBarcode(input));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーコードを読み取る'),
        actions: [
          TextButton(onPressed: _enterManually, child: const Text('番号を入力')),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _CameraError(error: error, onEnterManually: _enterManually),
          ),
          // 読み取る位置の目安
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.8,
                child: AspectRatio(
                  aspectRatio: 2.2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              '商品のバーコードを枠の中に写してください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// カメラが使えないときの表示
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onEnterManually});

  final MobileScannerException error;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'カメラの使用が許可されていません。ブラウザの設定でカメラを許可するか、番号を入力してください',
      MobileScannerErrorCode.unsupported =>
        'この端末・ブラウザではカメラで読み取れません。番号を入力してください',
      _ => 'カメラを起動できませんでした。番号を入力してください',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onEnterManually,
                child: const Text('番号を入力'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
