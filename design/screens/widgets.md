# ウィジェット構成

画面の文言・振る舞いの仕様は [spec/03_view.md](../../spec/03_view.md) を参照。ここでは実装上の構成を書く。

## 1. 共通の方針

- Material 3（`ColorScheme.fromSeed(seedColor: Colors.teal)`）。ライトテーマのみ。
- Firestore のデータは `categoriesProvider` / `itemsProvider` を `ref.watch` して表示する。どちらかがエラーなら「読み込めませんでした。通信状態を確認してください」、読み込み中はインジケーターを表示する。
- 保存処理は `runWithErrorMessage` で包み、失敗したら SnackBar「保存できませんでした。通信状態を確認してください」を出す。
- 更新日時は `formatRelativeTime`（`core/utils/relative_time.dart`）で「たった今」「N分前」などにする。表示はデータが変わって描き直されたときに更新され、時間の経過だけでは更新しない。
- 名前の比較・並べ替えには `normalizeForCompare`（`core/utils/text_normalizer.dart`）を使う。前後の空白を除き、全角英数字を半角に、カタカナをひらがなに、英字を小文字にそろえる。
- 更新者・担当者は、表示名をそのまま表示する（「さん」は付けない。表示名に「お父さん」などを設定する想定）。

## 2. 共通ウィジェット（`shared/widgets/`）

| ファイル | 内容 |
|---|---|
| `confirm_dialog.dart` | `showConfirmDialog`: 確認ダイアログ。OK で true。`destructive` で OK ボタンをエラー色にする（削除用） |
| `text_input_dialog.dart` | `showTextInputDialog`: 1 行入力のダイアログ。`validator` は前後の空白を除いた値で呼ばれる。保存で値を、キャンセルで null を返す |
| `snack_bars.dart` | `showMessage`: SnackBar を出す（前の SnackBar は閉じる）。`runWithErrorMessage`: 保存処理を実行し、失敗したらエラーを表示して null を返す |

items 機能の中で共通に使うもの（`features/items/presentation/`）:

| ファイル | 内容 |
|---|---|
| `status_selector.dart` | `StatusSelector`: 3 段階の `SegmentedButton`。横幅いっぱい、選択中の背景をステータスの色（25% の濃さ）にする |
| `status_colors.dart` | ステータスの色（十分=緑・残りわずか=黄・切れてる=赤）と、薄い背景の上の文字色 |
| `item_actions.dart` | `changeItemStatus`（「十分」にするとき、ほかの人の担当があれば確認）、`deleteItemWithConfirm`、`purchaseLabel`（「🛒 〇〇が買う予定」などの文） |
| `item_edit_sheet.dart` | `showItemEditSheet` / `ItemEditSheet`: 追加・編集のボトムシート |

## 3. 画面ごとの構成

### 在庫一覧（`StockPage`）

```
Scaffold
├─ AppBar「在庫一覧」
├─ body: _StockList（ListView）
│  └─ カテゴリごとに（order 順）
│     ├─ 見出し「カテゴリ名（件数）」
│     └─ ItemCard × アイテム数
└─ FloatingActionButton（＋）→ showItemEditSheet
```

- アイテムは、カテゴリの中で `normalizeForCompare` した名前の順に並べる。ステータスが変わっても位置は動かない。漢字は文字コード順になり、読みの順にはならない。
- アイテムが 0 件のカテゴリも見出しを出す（件数 0）。アイテムが 1 件もないときは案内文だけを表示する。
- `ItemCard`: 名前、︙メニュー（編集・削除）、メモ（1 行で省略）、`StatusSelector`、「更新者・日時」、担当・カゴ済みがあればその文。
- **未実装**: 検索バー、カテゴリフィルター、ステータス変更後の「元に戻す」SnackBar。

### アイテム追加・編集（`ItemEditSheet`）

- `showModalBottomSheet`（`isScrollControlled`, `useSafeArea`, `showDragHandle`）。キーボードの高さ分だけ下に余白を入れる。
- `Form`（`AutovalidateMode.onUserInteraction`）で、入力中もエラーを表示する。
  - アイテム名: 必須・50 文字まで・ほかのアイテムと同じ名前は不可（エラーにカテゴリ名を出す）。
  - カテゴリ: `DropdownButtonFormField`。末尾の「＋ カテゴリ追加」で `showTextInputDialog` を開き、追加したカテゴリを選んだ状態にする。キャンセルしたら選択を元に戻す（`key` を変えて作り直す）。
  - ステータス: `StatusSelector`。
  - メモ: 200 文字まで、2〜5 行。
- 保存時、選んでいたカテゴリがほかの人に削除されていたら「その他」にする。
- 編集中にほかの人がアイテムを削除したら、シートを閉じて「このアイテムは削除されました」と表示する。
- 初期値: カテゴリは「その他」（呼び出し元が指定した場合はそのカテゴリ）、ステータスは「十分」（買い物リストから開いたときは「切れてる」）。カテゴリフィルターが未実装のため、在庫一覧からはカテゴリを指定していない。

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

- 並び順（各セクション内）: ① ほかの人がカゴ済みのものを末尾に、② カテゴリの `order` 順、③ 名前の順。
- `_ShoppingTile`: チェックボックス、名前、メモ（全文）、「カテゴリ・更新者・日時 ステータスに変更」、担当・カゴ済みの文（24 時間以上前なら「（1日以上前）」を付けて薄く表示）、操作ボタン。
- 操作ボタン:

| 状態 | ボタン | チェックボックス |
|---|---|---|
| 未担当 | 「買います」 | 押せる（自分が担当してカゴ済み） |
| 自分の担当中 | 「やめる」 | 押せる |
| ほかの人の担当中 | 「代わりに買う」（確認あり） | 押せる（確認あり） |
| 自分のカゴ済み | なし | 外せる（担当中に戻る） |
| ほかの人のカゴ済み | なし | 押せない（行全体を 50% の薄さで表示） |

- 「購入完了」: 自分のカゴ済みが 0 件なら押せない。押すと確認ダイアログを出し、OK で一括更新して「N件を購入完了にしました」と表示する。仕様の「元に戻す」SnackBar は**未実装**で、代わりに確認ダイアログを出している。
- 処理の流れは [sequences/shopping.md](../sequences/shopping.md) を参照。

### 設定（`SettingsPage`）

- `ListTile` の一覧: 表示名（タップで `showTextInputDialog`、20 文字まで）、ログイン中のアカウントのメールアドレス、ログアウト（確認あり）。
- **未実装**: カテゴリ管理への入り口、アプリのバージョン表示。

### ログイン・アクセス権限エラー・スプラッシュ

- `LoginPage`: 「Googleでログイン」ボタン。ログイン中はボタンを押せなくし、`LinearProgressIndicator` を表示する。ポップアップを閉じた場合は「ログインがキャンセルされました」、それ以外の失敗は「ログインできませんでした（エラーコード）」。
- `NoAccessPage`: 表示した直後（最初のフレームの後）にサインアウトする。メールアドレスは `deniedEmailProvider` から表示する。
- `SplashPage`: `AccessStatus.error` のときだけ「接続できませんでした」「再試行」「ログアウト」を表示し、それ以外はインジケーター。
