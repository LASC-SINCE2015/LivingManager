# アプリをビルドし、設定ファイルに書かれた Firebase プロジェクトへデプロイする。
#
# 使い方（リポジトリ直下で実行）:
#   ./tools/deploy.ps1 -EnvFile <設定ファイルのパス>
#   ./tools/deploy.ps1 -EnvFile <設定ファイルのパス> -Only hosting
#   ./tools/deploy.ps1 -EnvFile <設定ファイルのパス> -Yes   … 本番の確認を省く
#
# デプロイ先のプロジェクトは、設定ファイルの FIREBASE_PROJECT_ID から決める。
# ビルドに使う設定値とデプロイ先が必ず一致するので、テスト環境の設定で
# 本番にデプロイする（またはその逆）といった取り違えが起きない。
# 本番（APP_ENV が prod）へのデプロイは、実行前に確認を求める。
# 対話できない環境（自動実行など）では確認の入力ができないため、
# 本番に出すことを決めたうえで -Yes を付けて確認を省く。
#
# 必要なもの: Flutter、Firebase CLI（firebase login 済み）

param(
    # 設定ファイル（firebase_env.example.json と同じ形式）のパス
    [Parameter(Mandatory = $true)]
    [string]$EnvFile,

    # デプロイする対象（例: hosting / firestore:rules）。省略時はすべて
    [string]$Only,

    # 本番へのデプロイの確認を省く（対話できない環境で使う）
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $EnvFile)) {
    Write-Error "設定ファイルが見つかりません: $EnvFile"
}
$envPath = (Resolve-Path $EnvFile).Path
$config = Get-Content -Path $envPath -Raw -Encoding UTF8 | ConvertFrom-Json

$projectId = $config.FIREBASE_PROJECT_ID
$appEnv = $config.APP_ENV
if (-not $projectId) {
    Write-Error '設定ファイルに FIREBASE_PROJECT_ID がありません。'
}
if ($appEnv -ne 'prod' -and $appEnv -ne 'dev') {
    Write-Error '設定ファイルの APP_ENV は prod か dev にしてください。'
}

$label = if ($appEnv -eq 'prod') { '本番' } else { 'テスト環境' }
Write-Output "デプロイ先: $label（$projectId）"
if ($appEnv -eq 'prod' -and $Yes) {
    Write-Output '-Yes が指定されたため、確認を省いて本番にデプロイします。'
}
elseif ($appEnv -eq 'prod') {
    $answer = Read-Host '本番にデプロイします。よろしいですか？ (y/N)'
    if ($answer -ne 'y') {
        Write-Output '中止しました。'
        exit 0
    }
}

Push-Location (Join-Path $PSScriptRoot '..\app')
# flutter / firebase は案内文を標準エラーに出すことがあり、Stop のままだと
# 成功していても止まる。成否は終了コードで判定する。
$ErrorActionPreference = 'Continue'
try {
    & flutter build web "--dart-define-from-file=$envPath"
    if ($LASTEXITCODE -ne 0) {
        throw "ビルドがエラーで終了しました（終了コード: $LASTEXITCODE）。"
    }

    $deployArgs = @('deploy', '--project', $projectId)
    if ($Only) {
        $deployArgs += @('--only', $Only)
    }
    & firebase @deployArgs
    if ($LASTEXITCODE -ne 0) {
        throw "デプロイがエラーで終了しました（終了コード: $LASTEXITCODE）。"
    }
}
finally {
    Pop-Location
}

Write-Output "$label（$projectId）へのデプロイが終わりました。"
