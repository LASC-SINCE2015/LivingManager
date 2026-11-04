# 導入手順書（自分の家族用の環境を立ち上げる）

「おうちストック」を自分の家族でも使いたい方向けに、自分の Firebase プロジェクトを作り、自分専用の環境を立ち上げる手順をまとめます。

データ（アイテム・カテゴリ・購入履歴など）と、使えるアカウントの一覧は、あなたが作る Firebase プロジェクトの中だけに保存されます。ほかの家庭の環境とは一切つながりません。

> **まずはデモで試せます。** 環境を作る前に、操作感を [デモ（お試し版）](https://lasc-since2015.github.io/LivingManager/) で確かめられます。デモはサーバーを使わずブラウザの中だけで動き、ログインも不要です。入力した内容はどこにも保存されず、読み込み直すとサンプルの状態に戻ります。

## 目次

1. [このアプリでできること・費用](#1-このアプリでできること費用)
2. [必要なもの](#2-必要なもの)
3. [リポジトリをフォーク・クローンする](#3-リポジトリをフォーククローンする)
4. [Firebase プロジェクトを用意する](#4-firebase-プロジェクトを用意する)
5. [設定ファイルを作る](#5-設定ファイルを作る)
6. [デプロイする](#6-デプロイする)
7. [最初の利用者（管理者）を登録する](#7-最初の利用者管理者を登録する)
8. [家族を追加する](#8-家族を追加する)
9. [任意: GitHub Actions で自動デプロイする](#9-任意-github-actions-で自動デプロイする)
10. [任意: テスト環境を用意する](#10-任意-テスト環境を用意する)
11. [更新を取り込む](#11-更新を取り込む)
12. [よくあるトラブル](#12-よくあるトラブル)

---

## 1. このアプリでできること・費用

### できること

家族で日用品の在庫状況（十分 / 残りわずか / 切れてる）をリアルタイムに共有する Web アプリ（PWA）です。スマホ・PC のブラウザから使え、ホーム画面に追加するとアプリのように起動できます。

- 在庫一覧（カテゴリ別・検索・絞り込み・並べ替え）とステータスの切り替え
- 買い物リスト（「残りわずか」「切れてる」を自動で集める）、担当宣言（「買います」）、カゴ済みチェック、購入完了
- LINE で買い物を頼む（選んだアイテムを文面にして LINE を開く）
- 購入履歴（1 年で自動的に消える）、バーコードの登録と読み取り
- Google アカウントでのログイン。**許可したアカウントだけ** が使えます
- 改善意見の送信と、管理者（アプリ内では「開発者」）による一覧・ユーザー管理

機能の詳細は [spec/01_overview.md](../spec/01_overview.md) を参照してください。

### 費用

**Firebase の Spark（無料）プランの範囲で動きます。有料の Blaze プランへのアップグレードは不要です。** Cloud Functions など有料プランが必要な機能は使っていません（[design/decisions/0001_no_cloud_functions.md](../design/decisions/0001_no_cloud_functions.md)）。

使う Firebase の機能は次の 3 つです。

| 機能 | 用途 |
|---|---|
| Authentication | Google アカウントでのログイン |
| Cloud Firestore | 在庫などのデータの保存・リアルタイムの共有 |
| Hosting | アプリの公開（`https://<あなたのプロジェクトID>.web.app`） |

家族数人で使う程度であれば、無料枠を超えることはまずありません。万一超えた場合も、Spark プランのままなら課金はされず、上限に達した機能がしばらく（Firestore の読み書きならその日の残り）使えなくなるだけです。

GitHub Actions による自動デプロイ（[9 章](#9-任意-github-actions-で自動デプロイする)）を使う場合も、GitHub の無料枠の範囲で動きます。

---

## 2. 必要なもの

### アカウント

| アカウント | 用途 |
|---|---|
| Google アカウント | Firebase プロジェクトの作成・管理と、アプリへのログイン。家族もそれぞれ自分の Google アカウントでログインします |
| GitHub アカウント | リポジトリのフォーク（自分のコピーを作る）と、任意の自動デプロイ。クローンだけで使う場合はなくても構いません |

### PC にインストールするもの

| ツール | バージョン | 用途 |
|---|---|---|
| Git | 最新版 | リポジトリの取得・更新の取り込み |
| Flutter | stable。自動デプロイでは `3.47.8` を使っているので、同じ版がおすすめ | アプリのビルド |
| Node.js | 22 系（自動デプロイと同じ） | Firebase CLI の実行 |
| Firebase CLI | 最新版（自動デプロイでは `15.34.1`） | Firebase へのデプロイ。`npm install -g firebase-tools` で入ります |

- Flutter の Dart SDK は `^3.13.7` 以上が必要です（`app/pubspec.yaml` の `environment`）。
- 次のものは **アプリを動かすだけなら不要** です（開発をする場合に使います）。
  - Java 21 以上: Firestore ルールのテスト（エミュレーター）用
  - GitHub CLI（`gh`）: 自動デプロイの Secrets をコマンドで登録する場合のみ
- Windows では、デプロイに PowerShell のスクリプト（`tools/deploy.ps1`）を使えます。macOS・Linux では同じ内容のコマンドを直接実行します（[6 章](#6-デプロイする)）。

インストールできたか、次のコマンドで確認できます。

```bash
git --version
flutter --version
node --version
firebase --version
```

---

## 3. リポジトリをフォーク・クローンする

### フォークする（おすすめ）

自分の GitHub アカウントにリポジトリのコピーを作ります。自動デプロイを使う場合や、元のリポジトリの更新を取り込みやすくしたい場合はこちらにします。

1. 元のリポジトリの GitHub のページを開き、右上の「Fork」を押します。
2. 「Create a new fork」の画面で、Owner に自分のアカウントを選びます。
   - 「Copy the `master` branch only」にチェックを入れたままで構いません（`master` が公開用のブランチです）。
3. 「Create fork」を押します。

### クローンする

フォークしたリポジトリ（またはフォークせずに元のリポジトリ）を PC に取得します。

```bash
git clone https://github.com/<あなたのGitHubアカウント>/LivingManager.git
cd LivingManager
```

以降、**リポジトリ直下** はこの `LivingManager` フォルダのことです。

### 依存パッケージを取得する

```bash
cd app
flutter pub get
```

---

## 4. Firebase プロジェクトを用意する

すべて Firebase コンソール（https://console.firebase.google.com/ ）で、自分の Google アカウントでログインして行います。

### 4-1. プロジェクトを作る

1. 「プロジェクトを作成」（または「Firebase プロジェクトを始める」）を押します。
2. プロジェクト名を入力します（例: `ouchi-stock`）。
   - 名前の下に表示される **プロジェクト ID** を控えておきます。アプリの URL（`https://<プロジェクトID>.web.app`）にもなり、あとから変えられません。鉛筆のアイコンで変更できます。
3. 「続行」を押し、規約への同意などの画面を進めます。
4. Google アナリティクスの画面は、このアプリでは使わないので **オフ** にして構いません。
5. 「プロジェクトを作成」を押し、完了したら「続行」を押します。

作ったプロジェクトは Spark（無料）プランです。左下などに「アップグレード」の案内が出ても、押す必要はありません。

### 4-2. Web アプリを登録する

1. プロジェクトのトップ（「プロジェクトの概要」）で、「アプリを追加」→ Web のアイコン（`</>`）を押します。
2. 「アプリのニックネーム」に任意の名前（例: `おうちストック`）を入力します。
3. 「このアプリの Firebase Hosting も設定します。」に **チェックを入れます**（Hosting のサイトが一緒に用意されます）。
4. 「アプリを登録」を押します。
5. 「Firebase SDK の追加」に表示される `firebaseConfig` の値は、あとで [5 章](#5-設定ファイルを作る) の設定ファイルに使います（あとからいつでも確認できます）。
6. 「Firebase CLI のインストール」「Firebase Hosting へのデプロイ」の画面は、説明を読むだけで「次へ」「コンソールに進む」と進めて構いません（デプロイは [6 章](#6-デプロイする) で行います）。

### 4-3. Google ログインを有効にする

1. 左メニューの「構築」→「Authentication」を開き、「始める」を押します。
2. 「Sign-in method」タブで「Google」を選びます。
3. 「有効にする」をオンにし、「プロジェクトのサポートメール」で自分のメールアドレスを選んで「保存」を押します。
4. **ほかのログイン方法（メール / パスワードなど）は有効にしません。** このアプリは Google ログインだけを使います。
5. 「設定」タブ →「承認済みドメイン」に、次の 3 つがあることを確認します（通常は自動で入っています）。
   - `localhost`
   - `<あなたのプロジェクトID>.firebaseapp.com`
   - `<あなたのプロジェクトID>.web.app`

   独自ドメインを使う場合以外は、ここにほかのドメインを足す必要はありません。

### 4-4. Firestore を作る

1. 左メニューの「構築」→「Firestore Database」を開き、「データベースの作成」を押します。
2. エディションは「Standard」、データベース ID は `(default)` のままにします。
3. **ロケーション** を選びます。
   - **あとから変更できません。** 家族が住んでいる地域に近い場所を選んでください（日本なら `asia-northeast1`（東京）か `asia-northeast2`（大阪））。
   - 選んだロケーションによって無料で使える量が変わることはありません。
4. セキュリティルールは「**本番環境モード**」で開始します。
   - ここで作られるルールは「すべて拒否」です。このアプリのルール（`app/firebase/firestore.rules`）は、[6 章](#6-デプロイする) のデプロイで上書きされます。
   - 「テストモード」は誰でも読み書きできる状態になるので選ばないでください。
5. 「作成」を押します。

---

## 5. 設定ファイルを作る

アプリが接続する Firebase プロジェクトの値は、リポジトリに含めず、ビルドのときに設定ファイル（JSON）から渡します。

### 5-1. 設定ファイルをリポジトリの外にコピーする

`app/firebase_env.example.json` を、**リポジトリの外** の好きな場所にコピーします（例: リポジトリと同じ階層に `secret` フォルダを作り、`firebase_env.prod.json` という名前で置く）。

```bash
# 例: リポジトリ直下で実行
mkdir -p ../secret
cp app/firebase_env.example.json ../secret/firebase_env.prod.json
```

- リポジトリの中に置いてしまうと、誤ってコミット・公開してしまうおそれがあります。
  - 念のため `.gitignore` で `firebase_env.json`・`firebase_env.*.json`（`firebase_env.example.json` を除く）は無視するようにしてありますが、リポジトリの外に置くのが確実です。
- 以降、このファイルのパスを `<設定ファイルのパス>` と書きます。

### 5-2. 値を記入する

Firebase コンソールで、左上の歯車のアイコン →「プロジェクトの設定」→「全般」タブを開き、下の「マイアプリ」で 4-2 で登録した Web アプリを選びます。「SDK の設定と構成」で「構成」（Config）を選ぶと、`firebaseConfig` の値が表示されます。

それぞれの値を、設定ファイルの対応するキーに書き写します。

| 設定ファイルのキー | `firebaseConfig` の項目 |
|---|---|
| `FIREBASE_API_KEY` | `apiKey` |
| `FIREBASE_APP_ID` | `appId` |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_PROJECT_ID` | `projectId` |
| `FIREBASE_AUTH_DOMAIN` | `authDomain` |
| `FIREBASE_STORAGE_BUCKET` | `storageBucket` |
| `APP_ENV` | （下の説明を参照） |

```json
{
  "FIREBASE_API_KEY": "<apiKey の値>",
  "FIREBASE_APP_ID": "<appId の値>",
  "FIREBASE_MESSAGING_SENDER_ID": "<messagingSenderId の値>",
  "FIREBASE_PROJECT_ID": "<あなたのプロジェクトID>",
  "FIREBASE_AUTH_DOMAIN": "<あなたのプロジェクトID>.firebaseapp.com",
  "FIREBASE_STORAGE_BUCKET": "<storageBucket の値>",
  "APP_ENV": "prod"
}
```

Firebase CLI にログイン済みであれば（[6-1](#6-1-firebase-cli-にログインする)）、次のコマンドでも同じ値を表示できます。

```bash
firebase apps:sdkconfig web --project <あなたのプロジェクトID>
```

### APP_ENV の意味

| 値 | 意味 | 見た目 |
|---|---|---|
| `prod` | 本番（家族がふだん使う環境） | 帯なし |
| `dev` | テスト環境（動作確認用の別プロジェクト。[10 章](#10-任意-テスト環境を用意する)） | 画面の左上に「テスト」の帯が出て、タブの名前が「おうちストック（テスト）」になる |
| `demo` | デモ（Firebase を使わず、ブラウザの中のサンプルデータで動く。リポジトリ内の `app/demo_env.json` を使う。この手順書では使わない） | 画面の左上に「デモ」の帯が出る |

**家族用の環境を 1 つだけ作る場合は `prod` にしてください。** `APP_ENV` を空のままビルドすると本番として扱われますが、デプロイのスクリプトと自動デプロイは、`prod` か `dev` が書かれていないとデプロイしません。

---

## 6. デプロイする

アプリをビルドし、Firestore のルール・インデックスと Hosting を Firebase に出します。

### 6-1. Firebase CLI にログインする

```bash
firebase login
```

ブラウザが開くので、4 章でプロジェクトを作った Google アカウントでログインし、アクセスを許可します。

デプロイ先のプロジェクトは設定ファイルの `FIREBASE_PROJECT_ID` から決まるので、`firebase use` や `.firebaserc` の作成は不要です。

### 6-2. デプロイを実行する（Windows）

リポジトリ直下で、PowerShell から実行します。

```powershell
./tools/deploy.ps1 -EnvFile <設定ファイルのパス>
```

- `APP_ENV` が `prod` のときは「本番にデプロイします。よろしいですか？ (y/N)」と聞かれるので、`y` を入力します。
- 中身は「`flutter build web` → `firebase deploy`（Firestore のルール・インデックスと Hosting）」です。詳しくは [tools/README.md](../tools/README.md#deployps1) を参照してください。
- Hosting だけ・ルールだけを出したいときは `-Only hosting` / `-Only firestore` を付けます。

### 6-2'. デプロイを実行する（macOS・Linux など）

`tools/deploy.ps1` と同じことを、コマンドで直接行います。`app/` で実行します。

```bash
cd app

# ビルド（build/web に出力）
flutter build web --dart-define-from-file=<設定ファイルのパス>

# Firestore のルール・インデックスをデプロイ
firebase deploy --only firestore --project <あなたのプロジェクトID>

# Hosting をデプロイ
firebase deploy --only hosting --project <あなたのプロジェクトID>
```

- `--project` には、ビルドに使った設定ファイルの `FIREBASE_PROJECT_ID` と **同じ値** を指定してください（違うプロジェクトに出すと、別のプロジェクトにつながるアプリが公開されてしまいます）。
- ルールを Hosting より先に出すのは、新しいアプリが新しいルールを前提にすることがあるためです。

### 6-3. 開いてみる

デプロイが終わったら、`https://<あなたのプロジェクトID>.web.app` を開きます。ログイン画面が出れば成功です。

この時点では、まだ誰も利用を許可されていないので、Google でログインすると「アクセス権限がありません」の画面になります。次の 7 章で自分を登録します。

---

## 7. 最初の利用者（管理者）を登録する

このアプリは、Firestore の `allowedUsers` コレクションに登録されたメールアドレスのアカウントだけが使えます。また、そのうち `admin` が `true` のアカウントが **管理者（アプリ内の表示は「開発者」）** になり、家族の追加の依頼を承認したり、改善意見の一覧を見たりできます。

最初の 1 人（あなた）は、アプリからは追加できないので、Firebase コンソールから手作業で登録します。

1. Firebase コンソールで、左メニューの「構築」→「Firestore Database」を開き、「データ」タブを選びます。
2. 「コレクションを開始」を押します。
3. 「コレクション ID」に `allowedUsers` と入力して「次へ」を押します。
4. ドキュメントを次のように入力します。
   - **ドキュメント ID**: ログインに使う Google アカウントのメールアドレスを、**すべて小文字** で入力します（「自動 ID」は使いません）。
   - フィールドを 2 つ追加します（「フィールドを追加」で 2 つ目を足せます）。

     | フィールド | タイプ | 値 |
     |---|---|---|
     | `memo` | string | 誰のアカウントかのメモ（例: `本人（管理者）`。50 文字まで） |
     | `admin` | boolean | `true` |

5. 「保存」を押します。
6. アプリを開き直して（「アクセス権限がありません」の画面になっている場合は「もう一度確認する」を押して）ログインし、在庫一覧が表示されれば完了です。
   - 最初にログインしたときに、カテゴリ「水回り」「その他」が自動で作られます。
   - 設定画面に「改善意見の一覧（開発者用）」「ユーザー管理（開発者用）」が出ていれば、管理者として登録できています。

> ドキュメント ID は大文字・小文字を区別します。アプリとルールはメールアドレスを小文字にしてから照合するので、大文字が混じっていると一致しません。

---

## 8. 家族を追加する

2 人目以降は、アプリの中の「追加の依頼」と「承認」で追加できます。Firebase コンソールを開く必要はありません。

1. 家族に、アプリの URL（`https://<あなたのプロジェクトID>.web.app`）を開いて、自分の Google アカウントでログインしてもらいます。
   - 「アクセス権限がありません」の画面になります。
2. その画面の「**管理者に追加を依頼する**」を押してもらいます（依頼は 1 アカウントにつき 1 件です）。
3. 管理者（あなた）が、設定 →「**ユーザー管理（開発者用）**」を開き、届いた依頼の「承認」を押します。
   - メモ（誰のアカウントか。例: `母`）と、その人も管理者にするかを決めて承認します。ふつうの家族は管理者にしなくて構いません。
   - 心当たりのない依頼は「却下」します（依頼が消えます）。
4. 家族に「**もう一度確認する**」を押してもらう（またはアプリを開き直してもらう）と、在庫一覧が表示されます。
5. スマホでは、ブラウザのメニューから「ホーム画面に追加」すると、アプリのように起動できます。

Firebase コンソールから手作業で追加することもできます（7 章と同じ手順で、`admin` を `false` にするか省きます）。

### 許可の変更・削除

アプリでできるのは追加だけです。メモや管理者の印の変更、許可の取り消しは Firebase コンソールで行います。

- 変更: 「Firestore Database」→ `allowedUsers` → 該当のドキュメントを選び、フィールドを編集します。
- 取り消し: 該当のドキュメントのメニュー（︙）→「ドキュメントを削除」。ログインしたままの端末でも、次の読み書きから拒否されます。
  - 必要であれば、「Authentication」→「ユーザー」タブからもそのアカウントを削除します。

---

## 9. 任意: GitHub Actions で自動デプロイする

フォークしたリポジトリでは、GitHub Actions（[.github/workflows/deploy.yml](../.github/workflows/deploy.yml)）で、ブランチへの push をきっかけに自動でデプロイできます。手元の PC からデプロイ（6 章）するだけで十分なら、この章は飛ばして構いません。

| ブランチへの push（マージ） | デプロイ先 | 使う Environment | 設定ファイルの `APP_ENV` |
|---|---|---|---|
| `master` | 本番 | `prod` | `prod` |
| `develop` | テスト環境 | `dev` | `dev` |

テスト環境を作らない（家族用の環境 1 つだけの）場合は、`prod` だけを用意し、`master` だけを使えば構いません。

### 9-1. Actions を有効にする

フォークしたリポジトリでは、ワークフローは最初は無効になっています。リポジトリの「Actions」タブを開き、「I understand my workflows, go ahead and enable them」を押して有効にします。

### 9-2. デプロイ用のサービスアカウントと鍵を作る（環境ごとに 1 回）

1. Google Cloud コンソール（https://console.cloud.google.com/ ）を、Firebase と同じ Google アカウントで開き、上部のプロジェクト選択で 4 章のプロジェクトを選びます。
2. 左メニュー（≡）→「IAM と管理」→「サービス アカウント」を開き、上の「＋ サービス アカウントを作成」を押します。
3. 「サービス アカウント名」に `github-deploy` などと入力し、「作成して続行」を押します。
4. 「ロールを選択」で次の 2 つを付け、「続行」→「完了」を押します。
   - 「Firebase 管理者」（検索欄に `Firebase 管理者` と入力）
   - 「＋ 別のロールを追加」→「Service Usage ユーザー」（英語表示では Service Usage Consumer）
5. 一覧の `github-deploy@...` を押し、「鍵」タブ →「鍵を追加」→「新しい鍵を作成」→「JSON」→「作成」を押します。JSON ファイルがダウンロードされます。
   - **この鍵があれば誰でもあなたのプロジェクトにデプロイできます。** リポジトリには絶対に入れず、Secrets に登録したら PC から削除してください。

### 9-3. GitHub の Environment を作る

1. フォークしたリポジトリの「Settings」→ 左メニューの「Environments」→「New environment」を押します。
2. 名前に `prod` と入力して「Configure environment」を押します。
3. 「Deployment branches and tags」を「No restriction」から「Selected branches and tags」に変え、「Add deployment branch or tag rule」で Ref type: Branch、Name pattern: `master` を追加します（「Add rule」）。
   - こうしておくと、ほかのブランチのワークフローからは Secrets を読めません。
   - 本番に出す前にボタンで承認したい場合は、「Required reviewers」にチェックを入れて自分を追加し、「Save protection rules」を押します（任意）。
4. テスト環境も使う場合は、同じように `dev` を作り、許可するブランチを `develop` にします。

### 9-4. Secrets を登録する

各 Environment の画面の「Environment secrets」→「Add environment secret」で、次の 2 つを登録します。値には、ファイルの中身を **すべて** 貼り付けます。

| 名前 | 中身 |
|---|---|
| `FIREBASE_ENV_JSON` | その環境の設定ファイル（5 章）の中身 |
| `FIREBASE_SERVICE_ACCOUNT` | 9-2 で作った鍵（JSON）の中身 |

GitHub CLI を使う場合（リポジトリ直下で。PowerShell の例）:

```powershell
Get-Content <設定ファイルのパス> -Raw | gh secret set FIREBASE_ENV_JSON --env prod
Get-Content <鍵のファイルのパス> -Raw | gh secret set FIREBASE_SERVICE_ACCOUNT --env prod
```

macOS・Linux では `gh secret set FIREBASE_ENV_JSON --env prod < <設定ファイルのパス>` のように、ファイルを標準入力で渡します。

登録できたら、鍵のファイルを削除します。

### 9-5. 動かしてみる

- `master` に push する（または「Actions」→「デプロイ」→「Run workflow」で `master` を選んで実行する）と、本番へのデプロイが走ります。
- ワークフローは、Secrets の設定ファイルの `APP_ENV` がブランチと合わない場合（`master` なのに `dev` など）や、鍵のプロジェクトが設定ファイルの `FIREBASE_PROJECT_ID` と違う場合は、デプロイせずに失敗します。
- 失敗したときは、「Actions」→「デプロイ」→ 失敗した実行 →「Re-run jobs」で実行し直せます。

---

## 10. 任意: テスト環境を用意する

アプリを改造したり、元のリポジトリの更新を取り込んだりするときに、家族のデータに影響を与えずに確認したい場合は、**本番とは別の Firebase プロジェクト** をテスト環境として作ります（[design/decisions/0011_separate_dev_project.md](../design/decisions/0011_separate_dev_project.md)）。費用は増えません（どちらも Spark プランのまま）。

1. 4 章の手順で、もう 1 つ Firebase プロジェクトを作ります（例: プロジェクト ID の末尾を `-dev` にする）。Firestore のロケーションは本番と同じにしておくと安心です。
2. 5 章の手順で、テスト環境用の設定ファイルを別に作り、`APP_ENV` を `dev` にします。
3. 6 章の手順で、テスト環境の設定ファイルを指定してデプロイします。
4. 7 章の手順で、テスト環境の `allowedUsers` にも自分を登録します（許可リストは本番とは別です）。

テスト環境でビルドしたアプリは、画面の左上に「テスト」の帯が出るので、本番と見分けられます。

手元の PC で動かして確認するときは、`app/` で次のように実行します。

```bash
flutter run -d chrome --dart-define-from-file=<テスト環境の設定ファイルのパス>
```

---

## 11. 更新を取り込む

元のリポジトリに機能追加や修正が入ったら、自分のフォークに取り込めます。

### GitHub の画面から（かんたん）

1. フォークしたリポジトリのページで、ブランチを `master` にします。
2. 「Sync fork」→「Update branch」を押します。
3. 自動デプロイ（9 章）を設定している場合は、これで本番にデプロイされます。設定していない場合は、PC で `git pull` してから 6 章の手順でデプロイします。

### コマンドで

```bash
# 最初の 1 回だけ: 元のリポジトリを upstream として登録する
git remote add upstream <フォーク元のリポジトリの URL>

# 取り込む
git checkout master
git fetch upstream
git merge upstream/master
git push origin master

# 依存パッケージを更新する
cd app
flutter pub get
```

- フォーク元のリポジトリの URL は、フォークしたリポジトリのページの上部（「forked from …」）のリンク先です。
- 自分で改造している場合は、マージで競合することがあります。テスト環境（10 章）がある場合は、先にテスト環境で確認してから本番に出すのがおすすめです。
- 更新に **Firestore のルール**（`app/firebase/firestore.rules`）の変更が含まれていることがあります。手動でデプロイする場合も、Hosting だけでなくルールも一緒にデプロイしてください（`tools/deploy.ps1` を `-Only` なしで実行すれば両方出ます）。
- スマホのホーム画面に追加したアプリは、開き直すと新しい版に切り替わります。切り替わらないときは、アプリを完全に閉じてから開き直してください。

---

## 12. よくあるトラブル

### ログインのポップアップが開かない・すぐ閉じる

- ブラウザがポップアップをブロックしていないか確認してください。このアプリはポップアップ方式で Google ログインします（[design/decisions/0004_login_with_popup.md](../design/decisions/0004_login_with_popup.md)）。
- 「承認済みドメイン」（4-3 の 5）に、開いている URL のドメインがあるか確認してください。独自ドメインなどで開いている場合は、そのドメインを追加します。

### ログインできたのに「アクセス権限がありません」になる

- `allowedUsers` のドキュメント ID が、ログインしたアカウントのメールアドレスと **完全に一致（小文字）** しているか確認してください。画面に表示されているメールアドレスと見比べます。
- 別のアカウントでログインしていないか確認してください（「別のアカウントでログイン」で切り替えられます）。
- テスト環境と本番の両方がある場合は、開いているアプリのプロジェクトの `allowedUsers` に登録したか確認してください。

### 在庫一覧などが表示されない・保存できない

- Firestore のルールがデプロイされているか確認してください。Firebase コンソールの「Firestore Database」→「ルール」タブに、`app/firebase/firestore.rules` と同じ内容が表示されていれば正しく出ています。出ていないときは `./tools/deploy.ps1 -EnvFile <設定ファイルのパス> -Only firestore`（または `firebase deploy --only firestore --project <あなたのプロジェクトID>`）を実行します。
- 設定ファイルの値が、別の Firebase プロジェクトのものになっていないか確認してください。

### `tools/deploy.ps1` が実行できない（Windows）

- 「このシステムではスクリプトの実行が無効になっているため…」と出る場合は、PowerShell の実行ポリシーで止められています。その場だけ許可して実行するには、次のようにします。

  ```powershell
  powershell -ExecutionPolicy Bypass -File ./tools/deploy.ps1 -EnvFile <設定ファイルのパス>
  ```

- 「設定ファイルに FIREBASE_PROJECT_ID がありません」「APP_ENV は prod か dev にしてください」と出る場合は、設定ファイルの記入漏れです（5-2）。
- Visual Studio Code のターミナルなど、確認の入力（`y`）ができない環境では、本番に出すことを決めたうえで `-Yes` を付けると確認を省けます。

### `firebase deploy` でエラーになる

- `firebase login` が済んでいるか、ログインしているアカウントがそのプロジェクトのオーナーか確認してください（`firebase login:list` で確認できます）。
- Hosting のサイトがないという内容のエラーが出る場合は、Firebase コンソールの「構築」→「Hosting」で「始める」を押し、最後まで進めてからデプロイし直してください。
- Firestore のデータベースがないという内容のエラーが出る場合は、4-4 の Firestore の作成が済んでいるか確認してください。

### 自動デプロイ（GitHub Actions）が失敗する

- 「設定ファイルの APP_ENV が … ではありません」: Secrets の `FIREBASE_ENV_JSON` の `APP_ENV` と、ブランチ（`master` は `prod`、`develop` は `dev`）が合っているか確認してください。
- 「サービスアカウントの鍵のプロジェクトが…違います」: `FIREBASE_SERVICE_ACCOUNT` に、別のプロジェクトの鍵を登録していないか確認してください。
- `403` や `PERMISSION_DENIED` が出る場合は、サービスアカウントのロール（9-2 の 4）が足りていません。エラーに出たロールを追加します。
- テスト環境を使わないのに `develop` ブランチを push すると、`dev` の Secrets がないため失敗します。`develop` を使わないか、テスト環境を用意してください。

### 鍵が漏れた・漏れたかもしれない

1. Google Cloud コンソールの「IAM と管理」→「サービス アカウント」→ `github-deploy` →「鍵」タブで、その鍵を削除します。
2. 新しい鍵を作り、Secrets の `FIREBASE_SERVICE_ACCOUNT` を登録し直します。

### 新しい版が反映されない

- Hosting の設定で、`html`・`js`・`json` はキャッシュしないようにしてあります（`app/firebase.json`）。それでも古いままのときは、ブラウザで再読み込み（PC は Ctrl + Shift + R など）するか、ホーム画面のアプリを完全に閉じて開き直してください。
