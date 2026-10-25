# design/ 配下の PlantUML（.puml）から、同じ場所に SVG を生成する。
#
# 使い方（リポジトリ直下で実行）:
#   $env:PLANTUML_JAR = "<plantuml.jar のパス>"
#   ./tools/render_diagrams.ps1
#
# 必要なもの: Java 21 以上、PlantUML の jar（MIT 版でよい）。
# 図は PlantUML 内蔵の smetana レイアウトを使うので Graphviz は不要。

param(
    # plantuml.jar のパス（省略時は環境変数 PLANTUML_JAR）
    [string]$Jar = $env:PLANTUML_JAR
)

$ErrorActionPreference = 'Stop'

if (-not $Jar -or -not (Test-Path $Jar)) {
    Write-Error 'plantuml.jar が見つかりません。-Jar で指定するか、環境変数 PLANTUML_JAR を設定してください。'
}

$designDir = Join-Path $PSScriptRoot '..\design'
$files = Get-ChildItem -Path $designDir -Recurse -Filter '*.puml'
if ($files.Count -eq 0) {
    Write-Output '.puml ファイルがありません。'
    exit 0
}

# 日本語を正しく読むため UTF-8 を指定する
& java -jar $Jar -charset UTF-8 -tsvg $files.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Error "PlantUML がエラーで終了しました（終了コード: $LASTEXITCODE）。"
}

Write-Output "$($files.Count) 件の SVG を生成しました。"
