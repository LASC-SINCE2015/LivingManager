# 確認結果: 2026-11-03 feature_dev_env（テスト環境の用意）

## 対象

- ブランチ: `feature_dev_env`（[#14](https://github.com/LASC-SINCE2015/LivingManager/pull/14)）、リリース: [#15](https://github.com/LASC-SINCE2015/LivingManager/pull/15)
- 内容: 本番とは別の Firebase プロジェクトをテスト環境にする（[0011](../../design/decisions/0011_separate_dev_project.md)）。テスト環境の表示、`tools/deploy.ps1`
- 確認内容: [test_plan.md](../test_plan.md)

## 環境

| 項目 | バージョン |
|---|---|
| OS | Windows 11 |
| Flutter | 3.47.8（stable） |
| Firebase CLI | 15.34.1 |

## 結果の概要

| 種類 | 結果 |
|---|---|
| 静的解析 | 未実施 |
| 単体テスト | 未実施 |
| ルールテスト | 未実施（ルールの変更なし） |
| ビルド・デプロイ | ✅ 合格（テスト環境・本番とも） |
| 実機確認 | ✅ 合格（テスト環境の表示・ログイン） |

## 詳細

### ビルド・デプロイ

| ID | 環境 | 結果 | 備考 |
|---|---|---|---|
| BD-01 | テスト環境 | ✅ | `tools/deploy.ps1` でビルド。出力: build/web |
| BD-02 | テスト環境 | ✅ | ルールのコンパイル成功・公開。インデックスも公開 |
| BD-03 | テスト環境 | ✅ | Hosting に公開。`version.json` が 1.0.5+6 |
| BD-01 | 本番 | ✅ | master へのマージ後にビルド。出力: build/web |
| BD-02 | 本番 | ✅ | ルールのコンパイル成功・公開（ルールの変更なし） |
| BD-03 | 本番 | ✅ | `/`・`/users`・`/no_access` が HTTP 200、`version.json` が 1.0.5+6 |

### 実機確認

| 確認内容 | 環境 | 結果 | 備考 |
|---|---|---|---|
| 「テスト」の帯・タブ名「おうちストック（テスト）」が出る | テスト環境 | ✅ | PC のブラウザで確認 |
| Google ログイン → 許可リストの判定 → 在庫一覧 | テスト環境 | ✅ | テスト環境の許可リストに開発者のアカウントを登録して確認 |
| 帯が出ず、タブ名が「おうちストック」のまま | 本番 | ✅ | PC のブラウザで確認 |

## 見つかった問題

- `tools/deploy.ps1` を Windows PowerShell 5.1 で `2>&1` つきで実行すると、flutter が標準エラーに出す案内文でスクリプトが止まった。→ 外部コマンドの成否を終了コードで判定するように直した（#14 に含む）。
- 本番へのデプロイの確認（`Read-Host`）は、対話できない環境（自動実行など）では使えず止まる。今回の本番デプロイは、スクリプトと同じ `flutter build web` と `firebase deploy --project <プロジェクトID>` を手で実行した。→ 確認を省く `-Yes` オプションを追加した（feature_deploy_yes）。
