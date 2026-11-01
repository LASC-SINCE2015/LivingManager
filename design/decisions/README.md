# 設計判断の記録 (decisions)

設計で迷ったことと、そう決めた理由を ADR（Architecture Decision Record）として残す。あとから「なぜこうなっているのか」を確認できるようにするため。

## 書き方

- ファイル名: `NNNN_<内容がわかる英語名>.md`（NNNN は 4 桁の通し番号）。
- 項目: 状態（採用 / 置き換え済み など）・日付・状況・決定・理由・影響。
- 決定を変えるときは、元の ADR を書き換えずに新しい ADR を作り、元の ADR の状態を「置き換え済み（NNNN）」にする。
- セキュリティに関わる判断はリポジトリでは管理しない。

## 一覧

| No | 内容 | 状態 |
|---|---|---|
| [0001](0001_no_cloud_functions.md) | Spark プランで運用し、Cloud Functions を使わない | 採用 |
| [0002](0002_claim_with_transaction.md) | 担当宣言はトランザクションで先着優先にする | 採用 |
| [0003](0003_sort_on_client.md) | 並べ替え・絞り込みはアプリ側で行う | 採用 |
| [0004](0004_login_with_popup.md) | Google ログインはポップアップ方式にする | 採用 |
| [0005](0005_purchase_does_not_change_updater.md) | 担当・カゴ済みだけの変更では更新者を変えない | 採用 |
| [0006](0006_item_order_per_user.md) | アイテムの並び順はユーザーごとに持つ | 採用 |
| [0007](0007_undo_sets_updater_to_self.md) | 「元に戻す」では更新者を自分にし、ほかの人の担当は戻さない | 採用 |
| [0008](0008_offline_from_cache_state.md) | オフライン判定は Firestore のキャッシュ状態を使う | 採用 |
| [0009](0009_feedback_in_app_for_developer.md) | 改善意見の一覧はアプリ内の別ページで、開発者だけが見る | 採用 |
| [0010](0010_user_request_in_app.md) | 利用するアカウントの追加は、アプリ内の依頼と開発者の承認で行う | 採用 |
| [0011](0011_purchase_history_cleanup_on_client.md) | 購入履歴は 1 年残し、期限切れの記録はアプリを開いたときに消す | 採用 |
| [0012](0012_barcode_with_mobile_scanner.md) | バーコードはアプリに登録した番号と照らし合わせ、読み取りは mobile_scanner を使う | 採用 |
| [0013](0013_line_request_by_share_url.md) | LINE で買い物を頼むときは、共有用の URL で LINE を開くだけにする | 採用 |
