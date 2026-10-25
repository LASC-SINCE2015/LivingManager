# テスト・確認 (testing)

LivingManager で「何を確認するか」と「確認した結果」を残すフォルダです。
テストコードそのものは app/ の中にあり、ここには確認の計画と記録だけを置きます。

## 目次

- [確認内容（テスト計画）](test_plan.md)
- 確認結果
  - [2026-10-25 feature_poc（PoC 初版）](results/2026-10-25_feature_poc.md)
  - [2026-10-25 feature_spec_completion（PoC で後回しにした機能）](results/2026-10-25_feature_spec_completion.md)

## 確認の種類

| 種類 | 対象 | 実行方法 | テストコードの場所 |
|---|---|---|---|
| 静的解析 | Dart のコード全体 | `flutter analyze`（app/ で実行） | app/analysis_options.yaml |
| 単体テスト | Flutter（ロジック） | `flutter test`（app/ で実行） | app/test/ |
| ルールテスト | Firestore セキュリティルール | `npm test`（app/firebase/ で実行。Java 21 以上が必要） | app/firebase/tests/ |
| ビルド | Web 版 | `flutter build web --dart-define-from-file=<設定ファイルのパス>` | − |
| 実機確認 | スマホ・PC のブラウザ | 手作業（[test_plan.md](test_plan.md) のチェックリスト） | − |

## 結果の残し方

- 確認したら `results/<日付>_<ブランチ名>.md` を作り、上の目次に追加する。
- 1 ファイルに「対象（ブランチ・コミット）」「環境」「種類ごとの結果」「見つかった問題」を書く。
- 失敗した確認も消さずに残し、直したら再確認の結果を追記する。
- 実行ログを貼る場合は、プロジェクト ID・URL・メールアドレスなどの環境固有の値を伏せる。
