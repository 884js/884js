# CLAUDE.md - 職務経歴書サイト自動生成の指示書

このリポジトリは GitHub ユーザー **884js** の職務経歴書サイトを自動生成するリポジトリです。
Claude Code が定期的にデータ収集・分析を行い、職務経歴書サイト（dist/index.html）を自動生成します。

## ワークフロー

### 1. データ収集
```bash
bash scripts/collect-github-data.sh
```
- `data/github-data.json` にJSON形式で出力される
- `gh` CLI を使用（`GH_TOKEN` 環境変数でPrivateリポジトリにもアクセス可能）
- Org リポジトリは `gh api user/orgs` で所属 Org を自動取得して収集
- PR取得は GraphQL で body/additions/deletions/changed_files を一括取得（並列実行）
- **24時間以内の再実行はスキップ**（`SKIP_IF_WITHIN_HOURS` で閾値変更可能）
- **離脱済み Org のデータは自動復元**（Org を辞めてもデータは消えない）
- **データは Cloudflare R2 に永続保存**（バケット: `884js-data`、ワークフロー実行ごとに get/put）
- **インクリメンタル更新**: PR データの SHA-256 ハッシュで変化を検知し、変化がない週は Claude 呼び出しをスキップ

### 2. 職務経歴書サイト生成

`templates/site/template.html` と `templates/site/styles.css` をベースに、`career.yml` と収集データを埋め込んで `dist/index.html` を生成する。

#### サイト生成ルール
- `templates/site/styles.css` を `dist/styles.css` にコピー
- `templates/site/template.html` のプレースホルダーを実データで置換して `dist/index.html` を生成
- レスポンシブ・ダークモード対応

### 3. 動的キャリア生成（JSON 出力方式）

`has_org: true` かつ `projects` が空の会社について、Claude が GitHub PR データを分析し JSON を出力する。

- **出力**: `data/career-json/{key}.json`（会社ごとの構造化データ）
- **HTML 変換**: `scripts/render-career.sh` が JSON → HTML に決定的に変換し、`dist/index.html` のプレースホルダーを置換
- **ハッシュスキップ**: PR データの SHA-256 ハッシュが前回と一致する場合、Claude 呼び出しをスキップして前回 JSON を再利用
- **差分更新**: 前回 JSON が存在する場合、Claude は既存の構造・文体を維持しつつ新規データの差分のみ反映

### 4. デプロイ（Cloudflare Pages）

サイト生成後、同一ワークフロー内で直接 Cloudflare Pages にデプロイする（`dist/` は git 管理外）。

- **デプロイツール**: `cloudflare/wrangler-action@v3`（`wrangler pages deploy`）
- **プロジェクト名**: `884js`
- **必要な GitHub Secrets**:
  - `CLOUDFLARE_API_TOKEN`: Cloudflare ダッシュボード → My Profile → API Tokens で作成（Cloudflare Pages Edit + R2 read/write 権限）
  - `CLOUDFLARE_ACCOUNT_ID`: Cloudflare ダッシュボードの URL またはサイドバーから取得

## career.yml の構成

### profile
- `name`: 氏名
- `summary`: 経歴サマリー
- `strengths`: 得意領域のリスト

### skills
- `languages`: プログラミング言語
- `frameworks`: フレームワーク・ライブラリ
- `tools`: ツール・インフラ
- `practices`: 設計・プロセス
- `devops`: DevOps

### companies
- `name`: 公開用の会社名
- `period`: 在籍期間
- `role`: 役職
- `business`: 事業内容
- `has_org`: GitHub Org のデータが取得可能か
- `projects`: プロジェクト単位の詳細情報
  - `has_org: true` かつ `projects` が空の場合、GitHub データから自動推定

## 職務経歴の生成ルール

### 重要: プライバシー保護

**絶対に公開してはいけない情報:**
- Org名（`gh api` で自動取得。コード・生成物に含めない）
- Privateリポジトリの具体的なリポジトリ名
- プロダクト名・サービス名・ドメイン固有の用語
- 社内ツール名や内部システム名

### 公開してよい情報
- `career.yml` に記載された全情報（name, period, role, business, projects）
- 使用技術スタック
- プロジェクトの種類（一般化した表現）
- 規模感（リポジトリ数、概算のコミット数、PR数）
- 担当領域（フロントエンド/バックエンド/インフラ等）

### 経歴生成の手順
1. `career.yml` の `projects` が定義されている会社はそのまま使用
2. `has_org: true` かつ `projects` が空の会社は、GitHub データ（org_repos, my_merged_prs）から自動推定
3. 具体的なリポジトリ名・プロダクト名・Org名は絶対に含めない

## PRデータの活用方法

- Org リポジトリの `my_merged_prs` からマージ済みPR総数を算出し Stats に表示
- PR の `additions` / `deletions` / `changed_files` からコード貢献の規模感を算出可能
- **Career セクション生成時の活用**: PR の title/body から担当した機能領域・技術的アプローチを推定（`has_org: true` かつ `projects` が空の会社が対象）

### PRデータのプライバシールール

- Org リポジトリのPRタイトル・body は一般化して表示するか非表示にする
- PR番号・マージ日時は統計情報として利用可能（リポジトリ名が紐づかない形であれば公開可）
- `additions` / `deletions` / `changed_files` は集計値として公開可能

## スキルセクションの生成ルール

- `career.yml` の `skills` セクションから全カテゴリを取得して表示
- カテゴリ分け: 言語 / フレームワーク / ツール / 設計・プロセス / DevOps

## テンプレートのプレースホルダー

### 出力例 (`templates/examples/`)
- `career-example.html` - Career セクションの HTML 出力例（CSS クラス・構成の参考）

### HTMLサイト (`templates/site/template.html`)
以下のプレースホルダーを実データで置換する:
- `{{USER_NAME}}` - ユーザー名
- `{{USER_BIO}}` - 自己紹介
- `{{USER_AVATAR}}` - アバターURL
- `{{SUMMARY_SECTION}}` - 概要・得意領域HTML
- `{{SKILLS_SECTION}}` - スキル一覧HTML
- `{{CAREER_SECTION}}` - 職務経歴HTML
- `{{STATS_SECTION}}` - 統計情報HTML
- `{{GENERATED_DATE}}` - 生成日時
