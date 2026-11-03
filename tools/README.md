# 開発用スクリプト (tools)

アプリ本体ではなく、デプロイやドキュメントの作成などに使うスクリプトを置くフォルダです。

| スクリプト | 用途 |
|---|---|
| [deploy.ps1](deploy.ps1) | アプリをビルドし、設定ファイルに書かれた Firebase プロジェクト（本番 / テスト環境）へデプロイする |
| [render_diagrams.ps1](render_diagrams.ps1) | design/ 配下の PlantUML（.puml）から SVG を生成する |
| [make_app_icon.java](make_app_icon.java) | アプリアイコン（app/web/icons/）と、ログイン画面のアイコン（app/assets/images/app_icon.png）の PNG を生成する |

## deploy.ps1

`flutter build web` と `firebase deploy` をまとめて手元から実行します（`develop`・`master` は [自動デプロイ](#自動デプロイgithub-actions) で出るので、主に機能ブランチをテスト環境で試すときに使います）。デプロイ先のプロジェクトは、ビルドに使う設定ファイルの `FIREBASE_PROJECT_ID` から決めるので、テスト環境の設定のまま本番にデプロイする、といった取り違えが起きません。設定ファイルの `APP_ENV` が `prod`（本番）のときは、実行前に確認を求めます。

### 必要なもの

- Flutter
- Firebase CLI（`firebase login` 済み）

### 実行（リポジトリ直下で）

```powershell
./tools/deploy.ps1 -EnvFile <設定ファイルのパス>
```

`-Only hosting` のように指定すると、その対象だけをデプロイします（省略時は Hosting と Firestore のルール・インデックスのすべて）。

本番へのデプロイの確認は、自動実行など対話できない環境では入力できません。本番に出すことを決めたうえで `-Yes` を付けると、確認を省いて実行します。

```powershell
./tools/deploy.ps1 -EnvFile <本番の設定ファイルのパス> -Yes
```

## 自動デプロイ（GitHub Actions）

ふだんのデプロイは GitHub Actions（[.github/workflows/deploy.yml](../.github/workflows/deploy.yml)）が自動で行います。`deploy.ps1` は、機能ブランチをテスト環境で試すときや、自動デプロイが使えないときに使います。

| ブランチへの push（マージ） | デプロイ先 | 使う Environment |
|---|---|---|
| `develop` | テスト環境 | `dev` |
| `master` | 本番 | `prod` |

- 手順は `deploy.ps1` と同じです（ビルド → Firestore のルール・インデックス → Hosting）。
- Secrets の設定ファイルの `APP_ENV` がブランチと合わない（`develop` なのに `prod` など）ときや、鍵のプロジェクトが設定ファイルの `FIREBASE_PROJECT_ID` と違うときは、デプロイせずに失敗します。
- 失敗したときは、リポジトリの「Actions」→「デプロイ」→ 失敗した実行 →「Re-run jobs」で実行し直せます。「Run workflow」で `develop` か `master` を選んで手で実行することもできます。

### 用意するもの（環境ごとに 1 回）

1. **デプロイ用のサービスアカウントと鍵**（Google Cloud コンソールの「IAM と管理」→「サービス アカウント」）
   - 名前の例: `github-deploy`
   - ロール: 「Firebase 管理者」と「Service Usage ユーザー」
   - 「鍵」タブで JSON の鍵を作る。鍵のファイルは Secrets に登録したら手元から消す。
2. **GitHub の Environment**（リポジトリの「Settings」→「Environments」）
   - `dev`: 「Deployment branches and tags」を「Selected branches and tags」にし、`develop` だけを許可する。
   - `prod`: 同じく `master` だけを許可する。本番に出す前に承認を挟みたいときは「Required reviewers」に承認する人を入れる。
   - ブランチを絞っておくと、ほかのブランチのワークフローからは Secrets を読めない。
3. **Environment の Secrets**（各 Environment の「Environment secrets」）

   | 名前 | 中身 |
   |---|---|
   | `FIREBASE_ENV_JSON` | その環境の設定ファイル（`app/firebase_env.example.json` と同じ形式）の中身 |
   | `FIREBASE_SERVICE_ACCOUNT` | 1 で作った鍵（JSON）の中身 |

   GitHub CLI を使う場合（リポジトリ直下で）:

   ```powershell
   Get-Content <設定ファイルのパス> -Raw | gh secret set FIREBASE_ENV_JSON --env dev
   Get-Content <鍵のファイルのパス> -Raw | gh secret set FIREBASE_SERVICE_ACCOUNT --env dev
   ```

## render_diagrams.ps1

設計書の図は PlantUML で書き、PlantUML がない人でも見られるように SVG も一緒にリポジトリに入れています。`.puml` を変更したら、このスクリプトで SVG を作り直してコミットしてください。

### 必要なもの

- Java 21 以上
- PlantUML の jar ファイル（https://github.com/plantuml/plantuml/releases の `plantuml-mit-<バージョン>.jar`）
- Graphviz は不要です（図は PlantUML 内蔵の smetana レイアウトを使います）。

### 実行（リポジトリ直下で）

```powershell
$env:PLANTUML_JAR = "<plantuml.jar のパス>"
./tools/render_diagrams.ps1
```

`-Jar <plantuml.jar のパス>` で直接指定することもできます。

## make_app_icon.java

アプリアイコン（にっこり顔のおうち＋チェックのバッジ）を Java の標準機能だけで描き、PNG に書き出します。アイコンの絵を変えたいときは、このファイルの色や図形を変更して実行し、できた PNG をコミットしてください。

### 必要なもの

- Java 11 以上（コンパイル不要で、ソースファイルを直接実行できます）

### 実行（リポジトリ直下で）

```powershell
java tools/make_app_icon.java app/web
```

次のファイルを作ります（`<版>` はスクリプトの `VERSION`。今は `v2`）。

| ファイル | サイズ | 備考 |
|---|---|---|
| `app/web/icons/icon-<版>-192.png` / `icon-<版>-512.png` | 192 / 512 | 角丸の背景 |
| `app/web/icons/icon-<版>-maskable-192.png` / `icon-<版>-maskable-512.png` | 192 / 512 | 背景を端まで塗り、絵を中央 80% に収める（Android のホーム画面で切り抜かれても欠けない） |
| `app/web/icons/icon-<版>-apple-180.png` | 180 | iPhone のホーム画面用。iPhone は透明な部分を黒く塗るので、端まで背景を塗る（角は iPhone が丸める） |
| `app/web/icons/icon-<版>-favicon-32.png` | 32 | ブラウザのタブ用 |
| `app/assets/images/app_icon.png` | 384 | ログイン画面に表示する画像（角丸の背景）。アプリに同梱するので、ファイル名に版は入れない |

### アイコンの絵を変えるとき

ホーム画面に追加済みのアプリやブラウザは、同じ URL の画像を古いまま使い続けることがあります。絵を変えたら、ファイル名を変えて新しい画像だとわかるようにします。

1. `make_app_icon.java` の `VERSION` を上げる（例: `v2` → `v3`）。
2. スクリプトを実行し、古い版の PNG を削除する。
3. `app/web/manifest.json` の `icons` と、`app/web/index.html` の `apple-touch-icon`・`icon` の参照を新しいファイル名に変える。

Android・PC の Chrome は、アプリを開いたときにアイコンの変更に気づくと、しばらくして自動で入れ替えます。iPhone は自動では変わらないので、ホーム画面から削除して追加し直します。
