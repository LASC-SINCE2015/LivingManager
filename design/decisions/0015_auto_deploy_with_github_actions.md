# 0015 develop・master へのマージで、GitHub Actions が自動でデプロイする

- 状態: 採用
- 日付: 2026-11-04

## 状況

テスト環境を用意し（[0011](0011_separate_dev_project.md)）、「機能ブランチ → develop → テスト環境で確認 → master → 本番」の流れで開発している。デプロイは `tools/deploy.ps1` を手元で実行していたため、マージのあとにデプロイを忘れたり、テスト環境と本番の中身がブランチとずれたりするおそれがあった。費用をかけず（[0001](0001_no_cloud_functions.md)）、PC に新しいツールを入れずに自動にしたい。

## 決定

- **GitHub Actions で、`develop` への push でテスト環境に、`master` への push で本番にデプロイする**（`.github/workflows/deploy.yml`）。
- 手順は `deploy.ps1` と同じにする（ビルド → Firestore のルール・インデックス → Hosting）。
- **設定値とデプロイ用のサービスアカウントの鍵は、GitHub の Environments（`dev` / `prod`）の Secrets に置く。** 各 Environment は決まったブランチ（`dev` は `develop`、`prod` は `master`）からしか使えないようにする。
- 取り違えを防ぐため、Secrets の設定ファイルの `APP_ENV` がブランチと合わないとき、鍵のプロジェクトが `FIREBASE_PROJECT_ID` と違うときは、デプロイしない。
- `master` へのマージを「本番に出す」決定とみなす。承認を挟みたいときは、`prod` の Environment に承認する人を設定する。
- `deploy.ps1` は残し、機能ブランチをテスト環境で試すときや、自動デプロイが使えないときに使う。

## 理由

- リポジトリは公開しているため、GitHub Actions は無料で使える。Firebase も Spark プランのままでよく、PC に入れるものもない。
- ブランチとデプロイ先が 1 対 1 に決まるので、「develop にあるもの ＝ テスト環境」「master にあるもの ＝ 本番」が常に成り立つ。
- Firebase CLI の `firebase init hosting:github` でも自動デプロイを作れるが、Hosting しか出さず、ルール・インデックスや、ビルド時の設定値（`--dart-define-from-file`）の受け渡しに対応していない。
- 鍵を使わない Workload Identity 連携もあるが、Google Cloud 側の設定が多い。家族向けの小さなアプリなので、Environment をブランチで絞ったうえで鍵を Secrets に置く方法にした。

## 影響

- サービスアカウントの鍵が漏れると、そのプロジェクトのルールやデータを変えられてしまう。鍵のファイルは Secrets に登録したら手元から消し、漏れた疑いがあるときは Google Cloud コンソールで鍵を無効にして作り直す。
- Flutter と Firebase CLI の版はワークフローに書いて固定している。手元の版を上げたら、ワークフローの版もそろえる。
- `master` へのマージがそのまま本番への公開になる。マージの前に、テスト環境での確認を済ませておく。
