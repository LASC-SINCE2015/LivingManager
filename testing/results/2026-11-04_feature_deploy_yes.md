# 確認結果: 2026-11-04 feature_deploy_yes（デプロイ用スクリプトの -Yes）

## 対象

- ブランチ: `feature_deploy_yes`（[#16](https://github.com/LASC-SINCE2015/LivingManager/pull/16)）、リリース: [#17](https://github.com/LASC-SINCE2015/LivingManager/pull/17)
- 内容: `tools/deploy.ps1` に、本番へのデプロイの確認を省く `-Yes` を追加
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
| 静的解析 | 未実施（Dart のコードの変更なし） |
| 単体テスト | 未実施（Dart のコードの変更なし） |
| ルールテスト | 未実施（ルールの変更なし） |
| ビルド・デプロイ | ✅ 合格（3/3） |
| 実機確認 | 対象外（画面・機能の変更なし） |

## 詳細

### スクリプト

| 確認内容 | 結果 | 備考 |
|---|---|---|
| 構文チェック | ✅ | エラー 0 件 |
| 対話できない環境で `-Yes` を付けて本番にデプロイ | ✅ | 確認の入力で止まらず、「確認を省いて本番にデプロイします」と表示して最後まで進んだ |

### ビルド・デプロイ（本番）

| ID | 結果 | 備考 |
|---|---|---|
| BD-01 | ✅ | master へのマージ後に `tools/deploy.ps1 -Yes` でビルド。出力: build/web |
| BD-02 | ✅ | ルールのコンパイル成功・公開（ルールの変更なし） |
| BD-03 | ✅ | `/`・`/users`・`/no_access` が HTTP 200、`version.json` が 1.0.6+7 |

## 見つかった問題

- なし
