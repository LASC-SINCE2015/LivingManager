# 設計書 (design)

LivingManager の設計書（どう作るか）を置くフォルダです。仕様（何を作るか）は [spec/](../spec/README.md) を参照してください。

## フォルダ構成

| フォルダ | 内容 |
|---|---|
| [architecture/](architecture/README.md) | フォルダ構成・層の分け方・Provider の関係・Firebase の使い方 |
| [data/](data/README.md) | Firestore のデータモデルと、アプリ側のクラスとの対応・書き込みの単位 |
| [screens/](screens/README.md) | 画面遷移・遷移先の判定・画面ごとのウィジェット構成 |
| [sequences/](sequences/README.md) | ログイン・買い物などの処理の流れ（シーケンス図） |
| [decisions/](decisions/README.md) | 設計判断の記録（ADR） |

## 実装状況の書き方

- 設計書は、現在の実装（app/）に合わせて書く。
- 仕様にはあるが作っていないものは「**未実装**」と明記する。
- PoC で後回しにした機能（検索・カテゴリフィルター、カテゴリ管理画面、「元に戻す」、オフライン表示、PC 用のサイドナビ、バージョン表示、ログイン後の戻り先、アイテムの並び順の手動設定）は、すべて実装済み。
- 仕様と実装の差: オフライン中の担当宣言など、トランザクションを使う操作は「接続が戻ったときに判定し直す」ことができず失敗する（[ADR 0002](decisions/0002_claim_with_transaction.md)）。

## 図

- 図は PlantUML（`.puml`）で書き、各フォルダの `diagrams/` に置く。
- md からは、同じ名前の SVG を参照する（PlantUML がなくても見られるようにするため）。
- Graphviz は不要（PlantUML 内蔵の smetana レイアウトを使う。各 `.puml` に `!pragma layout smetana` を入れる）。
- `.puml` を変更したら、[tools/](../tools/) のスクリプトで SVG を作り直し、`.puml` と `.svg` を一緒にコミットする。

※ アクセス制限の詳細と、API キーなどセキュリティに関わる実値はリポジトリでは管理しません。
