# 884js ポートフォリオ

個人でつくったアプリとツールを紹介する静的サイト。

- 本文・掲載先: `templates/site/template.html`
- スタイル: `templates/site/styles.css`
- 画像: `templates/site/assets/`
- 生成: `bash scripts/generate-site.sh` → `dist/`
- 確認: `python3 -m http.server 4173 --directory dist`
- GitHubプロフィール・技術スタック: `README.md`（サイト生成とは独立）

## 更新方針

- PC・スマートフォンともに、実際のアプリアイコンを添えた1列の作品一覧を表示する。
- 紹介文やプレビューは設けず、作品情報はLPにまとめる。READMEは主力の技術スタック・活動カード・サイトへのリンクにする。
- 説明は短く、利用できる公開ページにリンクする。
- 非公開リポジトリ、社内情報、認証情報を公開するHTMLに含めない。
- 公開先が未確定の作品にダミーのリンクを付けない。
- 掲載作品と公開状態はユーザーの指定に従う。
- 変更後はPC・スマートフォンの表示とリンクを確認する。

公開先は既存のCloudflare Pagesプロジェクト `884js`、本番ブランチは `master`。
公開操作はユーザーの依頼に従う。ローカルのデータや確認記録は公開しない。

## GitHub活動カード

- `.github/workflows/update-profile-stats.yml` が毎日06:17（日本時間）に公開・非公開の活動を1回集計し、`scripts/generate-profile-card.py` がPC用 `profile/card.svg` とスマホ用 `profile/card-mobile.svg` を更新する。
- READMEの専用カードは「ピクセルサイン」案。紫の配色、ピクセル文字の884js、技術スタックと活動3項目を1枚にまとめ、カードからLPへリンクする。640px以下ではスマホ用へ切り替える。
- 明暗の配色はSVG内で親ページの `color-scheme` に追従する。GitHubはテーマ指定のある `source` のmedia条件を上書きするため、READMEの `source` には画面幅だけを指定する。
- デザイン・技術スタックは `scripts/generate-profile-card.py`、文字の形は `templates/profile/wordmark.svg`。ピクセル文字にはSilkscreenのアウトラインを使い、ライセンスを同じフォルダに保存している。更新処理はPython標準ライブラリのみで動く。
- 集計には既存の Actions Secret `PROFILE_GITHUB_TOKEN` を使う。`884js` の classic PAT で `repo` と `read:user` が必要。組織の制限やSSO認証により、参照できないリポジトリは集計に含まれない。
- 非公開の活動から公開するのはコミット・PR・レビューの件数のみ。トークン、非公開リポジトリ名、コード、PR本文は保存・出力しない。
- 認証・集計・画像の検証に失敗したら更新を中止し、前回のカードを残す。カードのコミットには集計用PATではなく、workflowの `GITHUB_TOKEN` を使う。
- 手動更新: `gh workflow run update-profile-stats.yml --ref master`。実行結果とカード表示を確認する。LPのデプロイは行わない。
- 生成処理の確認: `python3 scripts/test-profile-card.py`。入力が不正な場合は前回の画像を保持することも確認する。

## 動作確認

生成後、リポジトリのルートで `python3 -m http.server 4174 --bind 127.0.0.1` を実行し、[確認ページ](http://127.0.0.1:4174/scripts/check-portfolio.html)を開く。掲載作品・公開先・画像と、PC・スマートフォン幅での表示を確認する。

生成先の `dist/` はGit管理外。UIアイコンは [Tabler Icons](https://tabler.io/icons) の [MITライセンス](templates/site/assets/tabler-license.txt) に従う。

## 本番に反映する

公開の依頼を受けたら、Cloudflareにログインした環境で生成後に実行する。

```sh
npx wrangler@4 pages deploy dist --project-name 884js --branch master
```
