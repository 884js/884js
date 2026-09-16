# 884js

林悠暉が個人で開発したアプリとツールの一覧。

[ポートフォリオを見る](https://884js.pages.dev/)

## アプリ

| 作品 | 概要 | 公開先 |
| --- | --- | --- |
| 一言日記 | 14文字で日記をつけるアプリ。 | [App Store](https://apps.apple.com/jp/app/id6763487075) |
| wish notes | やりたいことや願いを記録するアプリ。 | 公開準備中 |
| かぞくのパスワード帳 | 家族のパスワードや情報を管理するアプリ。 | [App Store](https://apps.apple.com/jp/app/id6796645047) |
| 無限リマインダー | 停止するまで繰り返し通知するアプリ。 | [App Store](https://apps.apple.com/jp/app/id6765719923) |

## ツール

| 作品 | 概要 | 公開先 |
| --- | --- | --- |
| workout-mcp | AIとの会話で筋トレの計画・記録を管理。 | 公開準備中 |
| Editor Tab Manager | 複数のエディタウィンドウをタブで切り替え。 | [GitHub](https://github.com/884js/editor-tab-manager) |
| Expo iOS Release | Expo製iOSアプリのリリース作業を支援。 | [GitHub](https://github.com/884js/expo-ios-release-agent-plugin) |
| agent-plugins | コードの変更前に自動保存するClaude Codeプラグイン。 | [GitHub](https://github.com/884js/agent-plugins) |

## ローカルで確認する

```sh
bash scripts/generate-site.sh
python3 -m http.server 4173 --directory dist
```

[ローカルプレビュー](http://localhost:4173)を開く。生成にはBash、プレビューにはPython 3を使う。

本文・スタイル・画像は `templates/site/` で管理する。生成先の `dist/` はGit管理外。

PCでは一覧から作品を選ぶと右のプレビューが切り替わる。スマートフォンではプレビューをダイアログで表示する。

UIアイコンには[Tabler Icons](https://tabler.io/icons)を使用している。[MITライセンス](templates/site/assets/tabler-license.txt)。

### 切り替え動作の確認

生成後、リポジトリのルートで `python3 -m http.server 4174 --bind 127.0.0.1` を実行し、[動作確認ページ](http://127.0.0.1:4174/scripts/check-portfolio.html)を開く。作品選択、公開先、スマートフォン表示の切り替えを確認し、結果を表示する。

## 本番に反映する

Cloudflareにログインした環境で、生成後に実行する。

```sh
npx wrangler@4 pages deploy dist --project-name 884js --branch master
```
