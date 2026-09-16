# 884js

林悠暉がつくったアプリと、小さなツールのポートフォリオ。

[ポートフォリオを見る](https://884js.pages.dev/)

## アプリ

| 作品 | 概要 | 公開先 |
| --- | --- | --- |
| 一言日記 | 14文字で残す、今日のこと。 | [App Store](https://apps.apple.com/jp/app/id6763487075) |
| wish notes | いつかの願いを、一冊のノートに。 | 公開準備中 |
| かぞくのパスワード帳 | 家族の大切な情報を、手元に。 | [App Store](https://apps.apple.com/jp/app/id6796645047) |
| 無限リマインダー | 止めるまで、繰り返し知らせる。 | [App Store](https://apps.apple.com/jp/app/id6765719923) |

## ツール

| 作品 | 概要 | 公開先 |
| --- | --- | --- |
| workout-mcp | AIとの会話で、筋トレの計画と記録を。 | 公開準備中 |
| Editor Tab Manager | いくつものエディタを、ひとつのタブバーに。 | [GitHub](https://github.com/884js/editor-tab-manager) |
| Expo iOS Release | iOSアプリのリリースを、AIエージェントと。 | [GitHub](https://github.com/884js/expo-ios-release-agent-plugin) |
| agent-plugins | AIが変更する前に、コードのセーブポイントを。 | [GitHub](https://github.com/884js/agent-plugins) |

## ローカルで確認する

```sh
bash scripts/generate-site.sh
python3 -m http.server 4173 --directory dist
```

[ローカルプレビュー](http://localhost:4173)を開く。生成にはBash、プレビューにはPython 3を使う。

本文・スタイル・画像は `templates/site/` で管理する。生成先の `dist/` はGit管理外。

## 本番に反映する

Cloudflareにログインした環境で、生成後に実行する。

```sh
npx wrangler@4 pages deploy dist --project-name 884js --branch master
```
