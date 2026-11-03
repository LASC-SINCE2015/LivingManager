/// 実行環境（本番 / テスト）。
///
/// 設定ファイルの `APP_ENV` を `--dart-define-from-file` でビルド時に受け取る。
/// 指定がないときは本番として扱う（本番の画面に「テスト」が出ないようにするため）。
enum AppEnv {
  prod,
  dev;

  static const AppEnv current =
      String.fromEnvironment('APP_ENV') == 'dev' ? AppEnv.dev : AppEnv.prod;

  /// テスト環境か
  static bool get isDev => current == AppEnv.dev;
}
