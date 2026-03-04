# CLAUDE.md - プロフィール自動生成の指示書

このリポジトリは GitHub ユーザー **884js** のプロフィール README リポジトリです。
Claude Code が定期的にデータ収集・分析を行い、README.md とポートフォリオサイトを自動生成します。

## ワークフロー

### 1. データ収集
```bash
bash scripts/collect-github-data.sh
```
- `data/github-data.json` にJSON形式で出力される
- `gh` CLI を使用（`GH_TOKEN` 環境変数でPrivateリポジトリにもアクセス可能）
- Org リポジトリは `gh api user/orgs` で所属 Org を自動取得して収集

### 2. README.md 生成

`data/github-data.json` と `career.yml` を読み込み、`templates/readme-template.md` の構成に従って `README.md` を生成する。

#### README 生成ルール
- **言語**: 日本語
- **フォーマット**: GitHub Flavored Markdown
- **バッジ**: shields.io を使用
- **セクション構成**: `templates/readme-template.md` に従う
- 生成した README.md はリポジトリルートに直接出力
- **職務経歴は README には含めない**（ポートフォリオサイトのみ）

### 3. ポートフォリオサイト生成

`templates/site/template.html` と `templates/site/styles.css` をベースに、収集データを埋め込んで `dist/index.html` を生成する。

#### サイト生成ルール
- `templates/site/styles.css` を `dist/styles.css` にコピー
- `templates/site/template.html` のプレースホルダーを実データで置換して `dist/index.html` を生成
- レスポンシブ・ダークモード対応

### 4. 変更のPR作成

生成したファイルに変更があれば、ブランチを作成してPRを出す:
```bash
BRANCH="chore/update-profile-$(date +%Y-%m-%d)"
git checkout -b "$BRANCH"
git add README.md dist/
git diff --cached --quiet || git commit -m "chore: update profile ($(date +%Y-%m-%d))"
git push -u origin "$BRANCH"
gh pr create --title "chore: update profile ($(date +%Y-%m-%d))" --body "プロフィールの自動更新"
```

## 会社別職務経歴の生成ルール

**職務経歴はポートフォリオサイト（dist/index.html）にのみ掲載する。README.md には含めない。**

### 重要: プライバシー保護

**絶対に公開してはいけない情報:**
- Org名（`gh api` で自動取得。コード・生成物に含めない）
- Privateリポジトリの具体的なリポジトリ名
- プロダクト名・サービス名・ドメイン固有の用語
- 社内ツール名や内部システム名

### 公開してよい情報
- `career.yml` の `name`（会社名）
- `career.yml` の `period`, `role`, `description`
- 使用技術スタック（リポジトリの言語・トピックから抽出）
- プロジェクトの種類（「ECプラットフォーム」「管理画面」等、一般化した表現）
- 規模感（リポジトリ数、概算のコミット数）
- 担当領域（フロントエンド/バックエンド/インフラ等）

### 経歴生成の手順
1. `career.yml` の各会社に対して、`gh api` で自動取得した Org のリポジトリデータ（`data/github-data.json` の `org_repos`）を参照
2. `name` を公開用の会社名として使用
3. リポジトリの言語・トピック情報から技術スタックを自動抽出
4. リポジトリの内容を一般化してプロジェクト概要を生成
5. 具体的なリポジトリ名・プロダクト名・Org名は絶対に含めない

## PRデータの活用方法

- Org リポジトリの `my_merged_prs` からマージ済みPR総数を算出し Stats に表示（個人リポジトリのPRは収集しない）
- PR の `additions` / `deletions` / `changed_files` からコード貢献の規模感を算出可能

### PRデータのプライバシールール

- 個人リポジトリのPRタイトル・body はそのまま表示可能
- Org リポジトリのPRタイトル・body は一般化して表示するか非表示にする
- PR番号・マージ日時は統計情報として利用可能（リポジトリ名が紐づかない形であれば公開可）
- `additions` / `deletions` / `changed_files` は集計値として公開可能

## スキルセクションの生成ルール

- `data/github-data.json` の `language_stats` からバイト数ベースで上位言語を抽出
- `personal_repos` と `org_repos` の `repositoryTopics` からフレームワーク・ツールを抽出
- shields.io バッジで表示
- カテゴリ分け: 言語 / フレームワーク / ツール・インフラ

## テンプレートのプレースホルダー

### README (`templates/readme-template.md`)
テンプレートは構成の指針であり、各セクションの内容はデータに基づいて動的に生成する。

### HTMLサイト (`templates/site/template.html`)
以下のプレースホルダーを実データで置換する:
- `{{USER_NAME}}` - ユーザー名
- `{{USER_BIO}}` - 自己紹介
- `{{USER_AVATAR}}` - アバターURL
- `{{SKILLS_SECTION}}` - スキル一覧HTML
- `{{CAREER_SECTION}}` - 職務経歴HTML
- `{{STATS_SECTION}}` - 統計情報HTML
- `{{GENERATED_DATE}}` - 生成日時
