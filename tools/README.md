# 開発用スクリプト (tools)

アプリ本体ではなく、ドキュメントの作成などに使うスクリプトを置くフォルダです。

| スクリプト | 用途 |
|---|---|
| [render_diagrams.ps1](render_diagrams.ps1) | design/ 配下の PlantUML（.puml）から SVG を生成する |

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
