---
name: generate-dynamic-career
description: "GitHub データを分析し、会社ごとの職務経歴 JSON を data/career-json/{key}.json に出力する。update-deploy-profile ワークフローから呼び出される。"
---

# 動的職務経歴セクション生成（JSON 出力）

GitHub データを分析し、`has_org: true` かつ `projects` が空の会社について、
職務経歴の構造化データを JSON ファイルとして出力する。

**重要: HTML は生成しない。JSON のみ出力する。**
HTML への変換は `scripts/render-career.sh` が決定的に行う。

## 重要: データ分析アプローチ

career.yml の情報をそのまま繰り返すのではなく、GitHub データ（PR title/body/additions/deletions）を
**実際に分析**して、career.yml には書かれていない具体的な技術的取り組みを推定・記載すること。

- career.yml の strengths と同じ内容を achievements に書くのは NG
- GitHub データから読み取れる実際の開発活動（機能開発、バグ修正、設計改善、CI/CD整備等）を反映させる

## 入力データ

- `data/github-data.json`: GitHub API から収集したデータ
- `career.yml`: 職務経歴データ（会社の role / business をコンテキストとして活用）
- `templates/examples/career-example.html`: 出力の構成・粒度の参考

## 出力

会社ごとに `data/career-json/{key}.json` を Write で出力する。

### 会社キーマッピング

| career.yml の会社名 | キー | Org 名 |
|---------------------|------|--------|
| 株式会社Medii | `medii` | `medii-jp` |
| 株式会社and.d | `andd` | `anddtokyo` |

### JSON フォーマット

```json
{
  "company_key": "medii",
  "projects": [
    {
      "name": "プロジェクト名（一般化済み）",
      "period": "2025-03 ~ 2025-06",
      "tech": ["TypeScript", "React", "Next.js"],
      "summary": "概要テキスト",
      "achievements": [
        "成果1",
        "成果2"
      ]
    }
  ]
}
```

## 差分更新モード

`data/career-json/{key}.json` が既に存在する場合、**差分更新モード**で動作する:

1. 既存の JSON ファイルを Read する
2. 既存のプロジェクト構造・文体をベースとして維持する
3. 新しい PR データの差分のみを反映する（プロジェクトの追加、成果の更新）
4. 既存のプロジェクト名・summary の文体を変更しない

既存 JSON がない場合はゼロから生成する。

## 生成手順

### Step 1: Org を特定する

- career.yml の会社名と上記マッピングを照合し、対象 Org を特定する
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

### Step 6: JSON を出力する

- 各会社のキーに対応するファイル（`data/career-json/medii.json`, `data/career-json/andd.json`）を Write で出力
- `templates/examples/career-example.html` を参考に構成・粒度を揃えること

## 制約

- CLAUDE.md のプライバシー保護ルールを厳守
- 日本語で生成すること
- `data/career-json/{key}.json` 以外のファイルは変更しない
- dist/index.html は変更しない（HTML 変換は render-career.sh が行う）
