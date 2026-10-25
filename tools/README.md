# 開発用スクリプト (tools)

アプリ本体ではなく、ドキュメントの作成などに使うスクリプトを置くフォルダです。

| スクリプト | 用途 |
|---|---|
| [render_diagrams.ps1](render_diagrams.ps1) | design/ 配下の PlantUML（.puml）から SVG を生成する |
| [make_app_icon.java](make_app_icon.java) | アプリアイコン（app/web/icons/）の PNG を生成する |

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

### アイコンの絵を変えるとき

ホーム画面に追加済みのアプリやブラウザは、同じ URL の画像を古いまま使い続けることがあります。絵を変えたら、ファイル名を変えて新しい画像だとわかるようにします。

1. `make_app_icon.java` の `VERSION` を上げる（例: `v2` → `v3`）。
2. スクリプトを実行し、古い版の PNG を削除する。
3. `app/web/manifest.json` の `icons` と、`app/web/index.html` の `apple-touch-icon`・`icon` の参照を新しいファイル名に変える。

Android・PC の Chrome は、アプリを開いたときにアイコンの変更に気づくと、しばらくして自動で入れ替えます。iPhone は自動では変わらないので、ホーム画面から削除して追加し直します。
