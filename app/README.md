# app（Flutter Web アプリ本体）

家庭内在庫管理アプリの本体です。フォルダ構成の考え方は [design/architecture/folder_structure.md](../design/architecture/folder_structure.md) を参照してください。

## 前提ツール

- Flutter（stable）
- Node.js（Firebase CLI とルールテスト用）
- Firebase CLI（`npm install -g firebase-tools`）
- Java 21 以上（Firestore エミュレーターの実行に必要）

## Firebase の設定値

設定値はリポジトリに含めません。`firebase_env.example.json` をリポジトリ外にコピーして Firebase コンソールの値を記入し、そのパスを `--dart-define-from-file` で指定してください（以下のコマンドの `<設定ファイルのパス>`）。

## よく使うコマンド（app/ で実行）

```bash
# 開発サーバーで起動
flutter run -d chrome --dart-define-from-file=<設定ファイルのパス>

# テスト・静的解析
flutter test
flutter analyze

# 本番ビルド（build/web に出力）
flutter build web --dart-define-from-file=<設定ファイルのパス>

# Firebase Hosting / Firestore ルールへデプロイ（プロジェクト ID は Firebase コンソールで確認）
firebase deploy --project <プロジェクトID>
```

## Firestore ルールのテスト（app/firebase/ で実行）

```bash
npm install
npm test
```
