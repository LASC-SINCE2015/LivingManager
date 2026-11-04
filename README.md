# LivingManager

暮らしの物品管理アプリ「おうちストック」。家族で日用品の在庫状況（十分 / 残りわずか / 切れてる）をリアルタイムに共有し、買い忘れ・重複買いを防ぐ Web アプリ（Flutter Web + Firebase）です。

自分の家族でも使いたい方は、[導入手順書（docs/setup_guide.md）](docs/setup_guide.md) を参照してください。自分の Firebase プロジェクト（無料の Spark プラン）で、自分専用の環境を立ち上げられます。操作感は、ログイン不要の [デモ（お試し版）](https://lasc-since2015.github.io/LivingManager/) で試せます。

## フォルダ構成

| フォルダ | 内容 |
|---|---|
| [spec/](spec/README.md) | 仕様書（何を作るか） |
| [design/](design/README.md) | 設計書（どう作るか）。図は PlantUML と SVG |
| [testing/](testing/README.md) | 確認内容（テスト計画）と確認結果 |
| [app/](app/README.md) | Flutter Web アプリ本体・Firestore ルール |
| [tools/](tools/README.md) | 開発用スクリプト（PlantUML → SVG など）・デプロイの方法 |

## デプロイ

`develop` にマージするとテスト環境に、`master` にマージすると本番に、GitHub Actions が自動でデプロイします（[tools/README.md](tools/README.md#自動デプロイgithub-actions)）。
