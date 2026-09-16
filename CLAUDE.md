# 884js ポートフォリオ

個人でつくったアプリとツールを紹介する静的サイト。

- 本文・掲載先: `templates/site/template.html`
- スタイル: `templates/site/styles.css`
- 画像: `templates/site/assets/`
- 生成: `bash scripts/generate-site.sh` → `dist/`
- 確認: `python3 -m http.server 4173 --directory dist`

## 更新方針

- PCは2列、スマートフォンは1列。作品ごとの色と実際のアイコンを使う。
- 説明は短く、利用できる公開ページにリンクする。
- 非公開リポジトリ、社内情報、認証情報を公開するHTMLに含めない。
- 公開先が未確定の作品にダミーのリンクを付けない。
- 掲載作品と公開状態はユーザーの指定に従う。
- 変更後はPC・スマートフォンの表示とリンクを確認する。

公開先は既存のCloudflare Pagesプロジェクト `884js`、本番ブランチは `master`。
公開操作はユーザーの依頼に従う。ローカルのデータや確認記録は公開しない。
