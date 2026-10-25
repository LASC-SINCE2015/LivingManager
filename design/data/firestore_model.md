# Firestore のデータモデル

フィールドの定義は [spec/02_data.md](../../spec/02_data.md) を参照。ここでは、アプリのクラスとの対応・変換・書き込みの単位を書く。

## 1. コレクションとクラスの対応

![ER 図](diagrams/er.svg)

元データ: [er.puml](diagrams/er.puml)

| コレクション | ドキュメント ID | domain のクラス | 読み書きする Repository |
|---|---|---|---|
| `users` | Authentication の uid | `Member`（`uid`, `displayName`） | `MemberRepository` |
| `categories` | 自動採番（初期カテゴリは `water` / `other`） | `Category`（`id`, `name`, `order`） | `ItemsRepository` |
| `items` | 自動採番 | `Item`、`purchase` は `Purchase` | `ItemsRepository` |

- `createdAt` は保存するが、domain のクラスには持たない（画面で使わないため）。`users` / `categories` の `updatedAt` も同様。
- アクセス制限の詳細はリポジトリでは管理しない。

## 2. 読み取りと変換

- 画面は `snapshots()` でコレクション全体を購読する（`watchCategories()` / `watchItems()`）。件数が少ない（家族 5 人の日用品）ため、絞り込みや並べ替えは Firestore のクエリではなくアプリ側で行う（[ADR 0003](../decisions/0003_sort_on_client.md)）。
- カテゴリは `order` の昇順に並べて返す。アイテムの並び順は画面側で決める（[screens/widgets.md](../screens/widgets.md)）。

Firestore のデータから domain のクラスに変換するときの決まり（`ItemsRepository._toItem` など）:

| 項目 | 値がない・不正なとき |
|---|---|
| `status` | 未知の値は `sufficient` として扱う（`StockStatus.fromValue`） |
| `purchase` | マップでなければ null（未担当） |
| `purchase.state` | 未知の値は `planned` として扱う（`PurchaseState.fromValue`） |
| `categoryId` | なければ `other` |
| 文字列（`name`, `memo`, `updatedByName` など） | なければ空文字 |
| 日時（`updatedAt`, `purchase.at`） | `Timestamp` でなければ null。保存直後でサーバー時刻が未確定のときも null になり、画面には「たった今」と表示する |

- アイテムの `categoryId` がどのカテゴリにも当てはまらない（カテゴリが削除された）場合、画面では「その他」に入れて表示する。

## 3. 書き込みの単位

### 共通

- 日時はすべて `FieldValue.serverTimestamp()`（サーバー時刻）で書く。
- 在庫情報（名前・カテゴリ・ステータス・メモ）を変えるときは、`updatedAt` / `updatedByUid` / `updatedByName` を一緒に書く（`_updatedFields`）。
- `purchase` だけを変えるとき（担当宣言・カゴ済みなど）は、更新者を変えない（[ADR 0005](../decisions/0005_purchase_does_not_change_updater.md)）。
- 更新者・担当者の名前には、その時点の表示名（`actorProvider`）を書く。あとから表示名を変えても、過去の記録は書き換えない。

### 操作ごとの書き込み

| 操作 | メソッド | 方式 | 書き込む内容 |
|---|---|---|---|
| 初回ログイン時のメンバー登録 | `MemberRepository.ensureExists` | get → なければ set | `displayName`（Google アカウントの名前、なければメールアドレスの @ より前。20 文字まで）, `createdAt`, `updatedAt` |
| 表示名の変更 | `updateDisplayName` | update | `displayName`, `updatedAt` |
| 初期カテゴリの作成 | `ItemsRepository.ensureInitialCategories` | カテゴリごとに get → なければ set | `water`（水回り・order 1）, `other`（その他・order 9999）。ID が固定なので、複数人が同時に作っても重複しない |
| カテゴリの追加 | `addCategory` | set（ID はクライアントで採番） | `order` は「その他」以外の最大値 + 1 |
| アイテムの追加 | `addItem` | add | `purchase: null`、`memo` は空でも文字列で保存、`createdAt`、更新者 |
| アイテムの編集 | `updateItem` | update | 名前・カテゴリ・ステータス・メモ・更新者。「十分」なら `purchase: null` |
| アイテムの削除 | `deleteItem` | delete | ― |
| ステータスの変更 | `changeStatus` | update | ステータス・更新者。「十分」なら `purchase: null` |
| 担当宣言・カゴ済み | `claim` | **トランザクション** | `purchase`（`state`, `byUid`, `byName`, `at`） |
| 担当をやめる | `release` | **トランザクション** | 自分の担当のときだけ `purchase: null` |
| カゴ済みのチェックを外す | `uncheck` | **トランザクション** | 自分のカゴ済みのときだけ `purchase.state: planned` |
| 購入完了 | `completePurchase` | **バッチ** | 対象アイテムすべてに `status: sufficient`, `purchase: null`, 更新者 |

カテゴリの名前変更・並べ替え・削除（削除時にアイテムを「その他」へ移す）は**未実装**（カテゴリ管理画面が未実装のため）。

## 4. トランザクション・バッチを使う操作

### 担当宣言・カゴ済み（`claim`）

ほぼ同時に 2 人が担当しようとしたとき、先に保存した人を優先するため、トランザクションで「読んでから書く」（[ADR 0002](../decisions/0002_claim_with_transaction.md)）。

1. アイテムを読む。存在しない、またはステータスが「十分」なら `ClaimItemGone` を返して何も書かない。
2. ほかの人の `purchase` がある場合:
   - ほかの人のカゴ済み → `ClaimConflicted(担当者名)`。
   - ほかの人の担当中で、画面で確認した「代わりに担当する相手」（`takeOverFromUid`）と違う → `ClaimConflicted(担当者名)`。
3. それ以外は `purchase` を自分の担当（`toCart` なら `in_cart`、そうでなければ `planned`）にして `ClaimSucceeded` を返す。

処理の流れは [sequences/shopping.md](../sequences/shopping.md) を参照。

### やめる・チェックを外す（`release` / `uncheck`）

読んだ時点で `purchase` が自分のものでなければ何もしない（その間にほかの人が代わりに担当していた場合に、その人の担当を消さないため）。

### 購入完了（`completePurchase`）

自分がカゴ済みにしたアイテムを 1 回のバッチでまとめて「十分」に戻す。一部だけ成功することはない。

## 5. 買い物の状況の移り変わり

![買い物の状況の状態遷移](diagrams/purchase_state.svg)

元データ: [purchase_state.puml](diagrams/purchase_state.puml)
