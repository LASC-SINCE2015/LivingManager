# フォルダ構成

## 前提

- **画面**: Flutter Web（PWA としてスマホのホーム画面に追加して使う）
- **状態管理**: Riverpod（Firestore のリアルタイム更新を画面に反映する）
- **画面遷移**: go_router
- **インフラ**: Firebase Spark（無料枠）— Authentication / Firestore / Hosting
  - Spark では Cloud Functions が使えないため、サーバー側のコードは持たない。
  - アプリはビルドした静的ファイルを Hosting で配信するだけ。データの保護は **Firestore セキュリティルール**が担う。

## 全体像

```
（リポジトリ直下）
├─ README.md
├─ .gitignore
├─ spec/                        … 仕様書（何を作るか）
├─ design/                      … 設計書（どう作るか）。用途別のフォルダに分ける（design/README.md）
├─ testing/                     … 確認内容と確認結果の記録
├─ tools/                       … 開発用スクリプト（PlantUML の図 → SVG の生成など）
└─ app/                         … Flutter プロジェクト（実行するものはすべてここ）
```

リポジトリ直下は「文書（spec / design / testing）」「開発用の道具（tools）」「コード（app）」に分ける。アプリの実行・ビルドに必要なものは app/ の中だけに置く。

## app/ の構成

```
app/
├─ pubspec.yaml                 … 依存パッケージ
├─ analysis_options.yaml        … 静的解析ルール
├─ firebase.json                … Hosting（build/web を公開）・Firestore・エミュレーター設定
├─ firebase_env.example.json    … 設定値のキー名の見本（値は空）
├─ web/                         … PWA 関連
│  ├─ index.html
│  ├─ manifest.json             … アプリ名・アイコン・全画面起動
│  ├─ favicon.png
│  └─ icons/                    … ホーム画面用アイコン（tools/make_app_icon.java で生成）
├─ lib/
│  ├─ main.dart                 … 起動処理（Firebase 初期化 → ProviderScope）
│  ├─ app.dart                  … MaterialApp.router（テーマ・画面遷移）
│  ├─ firebase_options.dart     … 設定値は --dart-define-from-file で受け取る
│  ├─ core/                     … アプリ全体の土台
│  │  ├─ firebase/              …   Firebase の各サービスの Provider
│  │  ├─ router/                …   go_router の定義・タブの枠
│  │  ├─ theme/                 …   テーマ
│  │  └─ utils/                 …   文字列の正規化・日時の表示（相対表示・日時の書式）などの関数
│  ├─ features/                 … 機能ごとのフォルダ
│  │  ├─ auth/                  …   ログイン・利用許可の判定・家族メンバー（表示名・自分の並び順）
│  │  ├─ items/                 …   在庫一覧（検索・絞り込み・並べ替え）・アイテム/カテゴリの読み書き・
│  │  │                             担当/カゴ済み・元に戻す・オフライン判定
│  │  ├─ shopping_list/         …   買い物リスト（items の data / domain を使う）
│  │  ├─ settings/              …   設定（表示名・カテゴリ管理・ログアウト・バージョン表示）
│  │  └─ feedback/              …   改善意見の送信・開発者用の一覧（状態・メモの管理）
│  └─ shared/widgets/           … 機能をまたいで使う共通ウィジェット（確認ダイアログなど）
├─ test/                        … Flutter のテスト（lib/ と同じ階層構造で置く）
└─ firebase/                    … Firestore 関連
   ├─ firestore.rules           … セキュリティルール（最重要）
   ├─ firestore.indexes.json    … 複合インデックス
   ├─ package.json              … ルールテスト専用の Node 環境
   └─ tests/                    … ルールのテスト（エミュレーターで実行）
```

### features/ の中の 3 層

層ごとの役割と Provider の関係は [layers.md](layers.md) を参照。

各機能フォルダは次の 3 層に分ける。依存の向きは `presentation → domain ← data`。

| 層 | 役割 | 置くもの |
|---|---|---|
| `domain/` | アプリの概念そのもの。Flutter や Firebase に依存しない | モデル（`Item`、`StockStatus` など） |
| `data/` | Firestore との読み書き | Repository |
| `presentation/` | 画面と状態管理 | 画面・ウィジェット・Riverpod の Provider |

- 新しい機能（例: 買い物リスト）は `features/<機能名>/` を追加する。ブランチ名 `feature_<機能名>` と対応させる。
- 2 つ以上の機能で使うウィジェットだけを `shared/widgets/` に置く。

## 設定値（秘密情報）の扱い

- Firebase の Web 設定値（apiKey など）はリポジトリに含めない。`app/firebase_env.example.json` と同じ形式の JSON をリポジトリ外に用意し、ビルド時にそのパスを渡す。

  ```bash
  flutter run -d chrome --dart-define-from-file=<設定ファイルのパス>
  ```

- `lib/firebase_options.dart` は `String.fromEnvironment` で値を読むだけなので、リポジトリに含めてよい。
- 補足: Web の設定値はビルド後の JS に含まれ、ブラウザから見える。厳密な秘密ではないが、方針としてリポジトリには置かない。実際の保護は Firestore ルールと Authentication で行う。

## Firestore ルールのテスト

公式のテストツール（`@firebase/rules-unit-testing`）は Node 用のため、`app/firebase/` だけ `package.json` を持つ。エミュレーターの実行には Java が必要。

## 将来の拡張

- Blaze プランに上げて Cloud Functions を使う場合は `app/functions/` を追加する。
- ネイティブアプリ化する場合は `flutter create --platforms android,ios .` で `android/` `ios/` を追加する。
