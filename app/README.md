# app（Flutter Web アプリ本体）

家庭内在庫管理アプリ「おうちストック」の本体です。フォルダ構成の考え方は [design/architecture/folder_structure.md](../design/architecture/folder_structure.md) を参照してください。

## 前提ツール

- Flutter（stable）
- Node.js（Firebase CLI とルールテスト用）
- Firebase CLI（`npm install -g firebase-tools`）
- Java 21 以上（Firestore エミュレーターの実行に必要）

## Firebase の設定値

設定値はリポジトリに含めません。`firebase_env.example.json` をリポジトリ外にコピーして Firebase コンソールの値を記入し、そのパスを `--dart-define-from-file` で指定してください（以下のコマンドの `<設定ファイルのパス>`）。

本番とテスト環境は別の Firebase プロジェクトです。設定ファイルも環境ごとに用意し、`APP_ENV` に `prod`（本番）か `dev`（テスト環境）を書きます。`dev` でビルドすると、画面の左上に「テスト」の帯が出ます。ふだんの開発・確認はテスト環境の設定ファイルで行ってください。

## よく使うコマンド（app/ で実行）

```bash
# 開発サーバーで起動
flutter run -d chrome --dart-define-from-file=<設定ファイルのパス>

# テスト・静的解析
flutter test
flutter analyze

# ビルド（build/web に出力）
flutter build web --dart-define-from-file=<設定ファイルのパス>
```

## デプロイ（リポジトリ直下で実行）

ビルドとデプロイは [tools/deploy.ps1](../tools/deploy.ps1) でまとめて行います。デプロイ先は設定ファイルの `FIREBASE_PROJECT_ID` で決まるので、ビルドに使った設定とデプロイ先が食い違うことはありません。

```powershell
# テスト環境へ
./tools/deploy.ps1 -EnvFile <テスト環境の設定ファイルのパス>

# 本番へ（実行前に確認を求めます）
./tools/deploy.ps1 -EnvFile <本番の設定ファイルのパス>

# Hosting だけ・ルールだけをデプロイするとき
./tools/deploy.ps1 -EnvFile <設定ファイルのパス> -Only hosting
./tools/deploy.ps1 -EnvFile <設定ファイルのパス> -Only firestore
```

流れは「機能ブランチ → develop にマージ → テスト環境にデプロイして確認 → master にマージ → 本番にデプロイ」です。

## Firestore ルールのテスト（app/firebase/ で実行）

```bash
npm install
npm test
```
