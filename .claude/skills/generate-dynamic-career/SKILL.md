---
name: generate-dynamic-career
description: "dist/index.html の <!-- DYNAMIC_CAREER:会社名 --> プレースホルダーを GitHub データで分析・生成した職務経歴 HTML で置換する。update-profile ワークフローから呼び出される。"
---

# 動的職務経歴セクション生成

dist/index.html に含まれる `<!-- DYNAMIC_CAREER:会社名 -->` プレースホルダーを、
GitHub データを分析して生成した職務経歴 HTML で置換する。

## 重要: データ分析アプローチ

career.yml の情報をそのまま繰り返すのではなく、GitHub データ（PR title/body/additions/deletions）を
**実際に分析**して、career.yml には書かれていない具体的な技術的取り組みを推定・記載すること。

- career.yml の strengths と同じ内容を achievements に書くのは NG
- GitHub データから読み取れる実際の開発活動（機能開発、バグ修正、設計改善、CI/CD整備等）を反映させる

## 入力データ

- `dist/index.html`: generate-site.sh で生成済みの HTML（DYNAMIC_CAREER プレースホルダーあり）
- `data/github-data.json`: GitHub API から収集したデータ
- `career.yml`: 職務経歴データ（会社の role / business をコンテキストとして活用）
- `templates/examples/career-example.html`: 出力の構成・粒度の参考

## 生成手順

1. dist/index.html を読み込み、`<!-- DYNAMIC_CAREER:会社名 -->` を探す
2. 各プレースホルダーについて以下の手順で HTML を生成:

### Step 1: Org を特定する

- career.yml の会社名・事業内容と、data/github-data.json の org_repos の org フィールドを照合し、対象 Org を特定する
- 対象 Org のリポジトリと my_merged_prs を分析対象にする

### Step 2: リリースPRを除外する

- PRタイトルに "リリース" "release" "deploy" "Staging" "staging" を含むPRはフィルタリングする
- これらは統計（リリース回数）としてのみ活用する
- 残ったPRを「機能開発PR」として分析対象にする

### Step 3: 機能開発PRをカテゴリ分類する

- PRタイトルのプレフィックス（[API], [Web], [DB設計] 等）やキーワードからカテゴリを推定
- カテゴリ例: API開発, フロントエンド改善, DB設計, AI/LLM機能, CI/CD整備, バグ修正, Shopifyカスタマイズ
- 各カテゴリのPR数・additions/deletions合計を算出する

### Step 4: カテゴリをプロジェクト単位に構造化する

- 2件以上のPRがあるカテゴリをプロジェクトとして生成する
- 各プロジェクトには以下を含める:
  - 一般化したプロジェクト名（ドメイン固有用語は使わない）
  - 期間（PRのmerged_at の最古〜最新から推定）
  - 技術スタック（PRの変更内容・リポジトリの言語情報から推定）
  - 概要（何を目的とした開発か）
  - 成果リスト（PRデータに基づく具体的な取り組み。PR件数や行数で規模感も示す）
- career.yml の role / business をコンテキストとして活用する

### Step 5: プライバシー一般化を適用する

- プロダクト固有の用語は一般化する
  - 例: "コンサル画面疾患・薬剤情報提供" → "専門家向け情報提供機能"
  - 例: "HubSpotアンケート→コンサル文" → "外部サービス連携による自動文書生成"
  - 例: "ゲストQ" → "ユーザー向け質問・回答機能"
- **Org名・リポジトリ名・プロダクト固有名は絶対に含めない**

3. 生成した HTML で `<!-- DYNAMIC_CAREER:会社名 -->` を置換して dist/index.html に書き戻す
4. templates/examples/career-example.html を参考に構成・粒度を揃えること

## 出力フォーマット

各プレースホルダーを、career-project div のリストで置換する。
既存の career-item div の中身（会社名・期間・役職・事業内容の後）に挿入される形になる。

## 制約

- CLAUDE.md のプライバシー保護ルールを厳守
- 日本語で生成すること
- dist/index.html 以外のファイルは変更しない
