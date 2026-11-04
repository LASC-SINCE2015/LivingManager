/// 実行環境（本番 / テスト / デモ）。
///
/// 設定ファイルの `APP_ENV` を `--dart-define-from-file` でビルド時に受け取る。
/// 指定がないときは本番として扱う（本番の画面に「テスト」が出ないようにするため）。
enum AppEnv {
  prod,
  dev,

  /// Firebase を使わず、端末のメモリ上のサンプルデータで動かす（お試し用）
  demo;

  static const AppEnv current = String.fromEnvironment('APP_ENV') == 'dev'
      ? AppEnv.dev
      : String.fromEnvironment('APP_ENV') == 'demo'
      ? AppEnv.demo
      : AppEnv.prod;

  /// テスト環境か
  static bool get isDev => current == AppEnv.dev;

  /// デモ（お試し版）か
  static bool get isDemo => current == AppEnv.demo;
}
