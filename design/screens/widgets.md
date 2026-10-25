# ウィジェット構成

画面の文言・振る舞いの仕様は [spec/03_view.md](../../spec/03_view.md) を参照。ここでは実装上の構成を書く。

## 1. 共通の方針

- Material 3（`ColorScheme.fromSeed(seedColor: Colors.teal)`）。ライトテーマのみ。
- Firestore のデータは `categoriesProvider` / `itemsProvider` を `ref.watch` して表示する。どちらかがエラーなら「読み込めませんでした。通信状態を確認してください」、読み込み中はインジケーターを表示する。
- 保存処理は `runWithErrorMessage` で包み、失敗したら SnackBar「保存できませんでした。通信状態を確認してください」を出す。
- 更新日時は `formatRelativeTime`（`core/utils/relative_time.dart`）で「たった今」「N分前」などにする。表示はデータが変わって描き直されたときに更新され、時間の経過だけでは更新しない。
- 名前の重複チェックと検索には `normalizeForCompare`（`core/utils/text_normalizer.dart`）を使う。前後の空白を除き、全角英数字を半角に、カタカナをひらがなに、英字を小文字にそろえる。
- アイテムの並び順は、在庫一覧・買い物リストとも自分の並び順（`myItemOrderProvider` と `sortByMyOrder`）で決める（[data/firestore_model.md](../data/firestore_model.md) の「自分の並び順」）。
- 更新者・担当者は、表示名をそのまま表示する（「さん」は付けない。表示名に「お父さん」などを設定する想定）。

## 2. 共通ウィジェット（`shared/widgets/`）

| ファイル | 内容 |
|---|---|
| `confirm_dialog.dart` | `showConfirmDialog`: 確認ダイアログ。OK で true。`destructive` で OK ボタンをエラー色にする（削除用） |
| `text_input_dialog.dart` | `showTextInputDialog`: 1 行入力のダイアログ。`validator` は前後の空白を除いた値で呼ばれる。保存で値を、キャンセルで null を返す |
| `snack_bars.dart` | `showMessage`: SnackBar を出す（前の SnackBar は閉じる）。`runWithErrorMessage`: 保存処理を実行し、失敗したらエラーを表示して null を返す。`showUndoMessage`: 「元に戻す」ボタン付きの SnackBar を 5 秒表示する（ボタン付きでも時間がたったら消える） |

items 機能の中で共通に使うもの（`features/items/presentation/`）:

| ファイル | 内容 |
|---|---|
| `status_selector.dart` | `StatusSelector`: 3 段階の `SegmentedButton`。横幅いっぱい、選択中の背景をステータスの色（25% の濃さ）にする |
| `status_colors.dart` | ステータスの色（十分=緑・残りわずか=黄・切れてる=赤）と、薄い背景の上の文字色 |
| `item_actions.dart` | `changeItemStatus`（「十分」にするとき、ほかの人の担当があれば確認。保存後に「元に戻す」付きのメッセージを出す）、`deleteItemWithConfirm`、`purchaseLabel`（「🛒 〇〇が買う予定」などの文） |
| `item_edit_sheet.dart` | `showItemEditSheet` / `ItemEditSheet`: 追加・編集のボトムシート |

## 3. 画面ごとの構成

### 在庫一覧（`StockPage`）

`StockPage` は `ConsumerStatefulWidget`。検索文字・選択中のカテゴリ・並べ替えモードかどうか・保存中の並び（`_pendingOrder`）を状態として持つ。

通常の表示:

```
Scaffold
├─ AppBar「在庫一覧」＋「並べ替え」ボタン（Icons.swap_vert）
├─ body: Column
│  ├─ _SearchArea
│  │  ├─ 検索欄（TextField。入力中は ✕ で消せる）
│  │  └─ カテゴリフィルター（横スクロールの ChoiceChip「すべて」＋各カテゴリ）
│  └─ _StockList（ListView）
│     └─ カテゴリごとに（order 順）
│        ├─ 見出し「カテゴリ名（件数）」
│        └─ ItemCard × アイテム数（自分の並び順）
└─ FloatingActionButton（＋）→ showItemEditSheet（選択中のカテゴリを初期値に）
```

- 検索: アイテム名とメモを `normalizeForCompare` して部分一致。空白だけの入力は検索なしとして扱う。カテゴリフィルターと同時に使うと、両方に合うものだけを出す。
- 検索・絞り込み中は 0 件のカテゴリを出さず、結果が 0 件なら「該当するアイテムがありません」。検索・絞り込みをしていないときは、0 件のカテゴリも見出しを出す。アイテムが 1 件もないときは案内文だけを表示する。
- アイテムはカテゴリの中で自分の並び順に並べる。ステータスが変わっても位置は動かない。
- `ItemCard`: 名前、︙メニュー（編集・削除）、メモ（1 行で省略）、`StatusSelector`、「更新者・日時」、担当・カゴ済みがあればその文。
- ステータスを変えると、`showUndoMessage`「『〇〇』を「切れてる」にしました [元に戻す]」を出す。元に戻す処理は [sequences/undo.md](../sequences/undo.md)。

並べ替えモード（「並べ替え」ボタンで切り替え）:

```
Scaffold
├─ AppBar「並べ替え中」＋「完了」ボタン
└─ body: _ReorderView（CustomScrollView）
   └─ カテゴリごとに（order 順、アイテムがあるカテゴリだけ）
      ├─ 見出し
      └─ SliverReorderableList
         └─ アイテム名だけの行 ＋ 右端のつまみ（ReorderableDragStartListener）
```

- 検索・絞り込み中に「並べ替え」を押すと、検索・絞り込みを解除してからモードに入る。モード中は検索欄・フィルター・＋ボタンを出さない。
- カテゴリごとに別の `SliverReorderableList` にしているため、ほかのカテゴリへは動かせない。行全体ではなくつまみだけでドラッグを始める（`buildDefaultDragHandles` を使わない）。ドラッグ中も外側の `CustomScrollView` が自動でスクロールする。
- 指を離したら `moveItem` で新しい並びを作り、`saveCategoryOrder` で保存する。保存が終わるまでは `_pendingOrder` の並びを先に表示し、失敗したら `_pendingOrder` を消して元の並びに戻し、エラーを表示する。処理の流れは [sequences/reorder.md](../sequences/reorder.md)。
- ほかのタブに切り替えたら通常の表示に戻す。go_router は非表示のタブを `TickerMode` で無効にするので、`didChangeDependencies` で `TickerMode.valuesOf(context).enabled` が false になったことを検知する。

### アイテム追加・編集（`ItemEditSheet`）

- `showModalBottomSheet`（`isScrollControlled`, `useSafeArea`, `showDragHandle`）。キーボードの高さ分だけ下に余白を入れる。
- `Form`（`AutovalidateMode.onUserInteraction`）で、入力中もエラーを表示する。
  - アイテム名: 必須・50 文字まで・ほかのアイテムと同じ名前は不可（エラーにカテゴリ名を出す）。
  - カテゴリ: `DropdownButtonFormField`。末尾の「＋ カテゴリ追加」で `showTextInputDialog` を開き、追加したカテゴリを選んだ状態にする。キャンセルしたら選択を元に戻す（`key` を変えて作り直す）。
  - ステータス: `StatusSelector`。
  - メモ: 200 文字まで、2〜5 行。
- 保存時、選んでいたカテゴリがほかの人に削除されていたら「その他」にする。
- 編集中にほかの人がアイテムを削除したら、シートを閉じて「このアイテムは削除されました」と表示する。
- 初期値: カテゴリは「その他」（呼び出し元が指定した場合はそのカテゴリ。在庫一覧ではカテゴリフィルターで選んでいるカテゴリ）、ステータスは「十分」（買い物リストから開いたときは「切れてる」）。

### 買い物リスト（`ShoppingListPage`）

```
Scaffold
├─ AppBar「買い物リスト」
├─ body: _ShoppingList（ListView）
│  ├─ 見出し「● 切れてる」 → _ShoppingTile × 件数
│  └─ 見出し「● 残りわずか」 → _ShoppingTile × 件数
├─ FloatingActionButton（＋）→ showItemEditSheet（切れてる）
└─ bottomNavigationBar: 「購入完了（N件）」ボタン
```

- 並び順（各セクション内）: ① ほかの人がカゴ済みのものを末尾に、② カテゴリの `order` 順、③ 同じカテゴリ内は自分の並び順。買い物リストでは並べ替えできない。
- `_ShoppingTile`: チェックボックス、名前、メモ（全文）、「カテゴリ・更新者・日時 ステータスに変更」、担当・カゴ済みの文（24 時間以上前なら「（1日以上前）」を付けて薄く表示）、操作ボタン。
- 操作ボタン:

| 状態 | ボタン | チェックボックス |
|---|---|---|
| 未担当 | 「買います」 | 押せる（自分が担当してカゴ済み） |
| 自分の担当中 | 「やめる」 | 押せる |
| ほかの人の担当中 | 「代わりに買う」（確認あり） | 押せる（確認あり） |
| 自分のカゴ済み | なし | 外せる（担当中に戻る） |
| ほかの人のカゴ済み | なし | 押せない（行全体を 50% の薄さで表示） |

- 「購入完了」: 自分のカゴ済みが 0 件なら押せない。押すと確認なしで一括更新し、`showUndoMessage`「N件を購入完了にしました [元に戻す]」を出す。元に戻したときに一部しか戻せなかった場合は「ほかの人が変更したため、N件は戻せませんでした」と表示する。
- 処理の流れは [sequences/shopping.md](../sequences/shopping.md) を参照。

### 設定（`SettingsPage`）

- `ListTile` の一覧: 表示名（タップで `showTextInputDialog`、20 文字まで）、ログイン中のアカウントのメールアドレス、カテゴリ管理（`/settings/categories` へ移動）、改善意見を送る（`/settings/feedback` へ移動）、改善意見の一覧（開発者用。`isDeveloperProvider` が true のときだけ表示し、`/feedback` へ移動）、ログアウト（確認あり）、バージョン（`appVersionProvider`。`version+buildNumber` の形）。

### カテゴリ管理（`CategoriesPage`）

```
Scaffold
├─ AppBar「カテゴリ管理」
├─ body: ReorderableListView
│  └─ _CategoryTile × カテゴリ数（order 順、「その他」は常に末尾）
│     ├─ カテゴリ名・所属アイテム数
│     ├─ つまみ（「その他」には出さない）
│     └─ ︙メニュー「削除」（「その他」には出さない）
└─ FloatingActionButton（＋）→ 名前を入力して追加
```

- 追加・名前変更は `showTextInputDialog`。入力チェックは `validateCategoryName`（`items/domain/category_name_rules.dart`。1〜20 文字・ほかのカテゴリと同じ名前は不可。名前変更では自分自身との重複を無視する）。追加は `ItemsRepository.addCategory`、名前変更は `CategoriesRepository.rename`。
- 並べ替え: `onReorderItem` で、移動先を「その他」より上に制限する。並べ終えたら `CategoriesRepository.reorder` で order を 1 から振り直す。
- 削除: 確認ダイアログ「『〇〇』を削除しますか？ このカテゴリのアイテム N 件は『その他』に移動します」のあと、`CategoriesRepository.delete`。
- 所属アイテム数は、存在しないカテゴリに属するアイテムを「その他」に数える（在庫一覧の表示に合わせる）。

### 改善意見を送る（`SendFeedbackPage`）

```
Scaffold
├─ AppBar「改善意見を送る」
└─ body: ListView
   ├─ 説明文
   ├─ SegmentedButton（不具合 / 要望 / その他。初期値は要望）
   ├─ TextField（本文。4〜8 行・最大 1000 文字の文字数カウンター付き）
   ├─ FilledButton「送信」（本文が空・送信中は押せない）
   └─ 送った意見（myFeedbackProvider）
      └─ _MyFeedbackTile × 件数（Card: 種類・本文（3 行まで、タップで全文）・送った日時・状態・_DevMemo（開発者のメモがあれば））
```

- 送信は `FeedbackRepository.submit`。入力チェックは `validateFeedbackBody`（`feedback/domain/feedback_rules.dart`）。送った人は `actorProvider`、バージョンは `appVersionProvider`（取得できなければ「不明」）。
- 成功したら本文を空にし、種類も「要望」に戻して「送信しました。ありがとうございます」と表示する。失敗したら入力内容を残して「送信できませんでした。通信状態を確認してください」と表示する。
- 日時は `formatDateTime`（`core/utils/date_format.dart`。`YYYY/MM/DD HH:mm`。保存中で未確定なら「送信中」）で表示する。

### 改善意見の一覧（`FeedbackListPage`）

```
Scaffold（HomeShell の外。ナビゲーションなし）
├─ AppBar「改善意見の一覧（開発者用）」＋ 戻るボタン（/stock へ）
└─ body: isDeveloperProvider の結果で切り替え
   ├─ 判定中: インジケーター
   ├─ 開発者でない・判定エラー: _NoPermission（「このページを見る権限がありません」＋ 在庫一覧へ戻るボタン）
   └─ 開発者: _FeedbackList（中央寄せ・最大幅 960px）
      ├─ 状態の ChoiceChip（すべて / 未対応 / 対応中 / 対応済み / 見送り。件数付き。初期値は未対応）
      ├─ 種類の ChoiceChip（すべて / 不具合 / 要望 / その他）
      └─ _FeedbackCard × 件数（新しい順）
         ├─ 種類・状態の DropdownButton（選んだ時点で updateStatus）・︙メニュー「削除」（確認ダイアログの後 delete）
         ├─ 本文（SelectableText。全文）
         ├─ 送った人・送った日時・バージョン
         └─ メモ ＋「メモを編集」→ _MemoDialog（最大 500 文字。「メモは送った本人にも表示されます」）
```

- 開発者でないときは `allFeedbackProvider` を購読しない（一覧を読み込まない）。
- 状態チップの件数は、種類で絞り込んだ後の一覧から数える（`countByStatus`）。絞り込みは `filterFeedback`。

### メイン画面の枠（`HomeShell`）

- 画面幅 768px 以上: `Row`（`NavigationRail`（ラベル表示・買い物リストに `Badge`）＋ 縦線 ＋ 各タブの画面）。
- 768px 未満: 各タブの画面 ＋ 画面下部の `NavigationBar`。
- オフライン表示: `isOfflineProvider` が true のとき、画面上部に「オフラインです。変更は接続が戻ると反映されます」のバナーを出す。バナーが上端の余白（ステータスバー分）を使うため、その下の画面からは上の余白を取り除く（`MediaQuery.removePadding`）。

### ログイン・アクセス権限エラー・スプラッシュ

- `LoginPage`: 「Googleでログイン」ボタン。ログイン中はボタンを押せなくし、`LinearProgressIndicator` を表示する。ポップアップを閉じた場合は「ログインがキャンセルされました」、それ以外の失敗は「ログインできませんでした（エラーコード）」。
- `NoAccessPage`: 表示した直後（最初のフレームの後）にサインアウトする。メールアドレスは `deniedEmailProvider` から表示する。
- `SplashPage`: `AccessStatus.error` のときだけ「接続できませんでした」「再試行」「ログアウト」を表示し、それ以外はインジケーター。
