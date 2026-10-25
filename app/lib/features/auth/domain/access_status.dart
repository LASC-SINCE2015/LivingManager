/// アプリを使えるかどうかの判定結果
enum AccessStatus {
  /// ログイン状態の確認中・利用の準備中
  checking,

  /// 未ログイン
  signedOut,

  /// ログインしたが、利用を許可されていないアカウント
  denied,

  /// 利用できる
  allowed,

  /// 通信エラーなどで判定できなかった
  error,
}
