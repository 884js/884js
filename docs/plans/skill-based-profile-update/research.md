# リサーチ: update-profile ワークフローのプロンプトをスキル化

調査日: 2026-03-08
調査タイプ: 複合（コードベース + 外部技術）

## 調査ゴール
update-profile.yml の Claude Code Action の長いインラインプロンプト（約65行）をプロジェクトスキルに切り出し、ワークフローではスキル呼び出しのみにする方法を明らかにする。

## 現状

### update-profile.yml の構造
- 4ステップ構成: データ収集(Bash) → 静的サイト生成(Bash) → Claude動的生成 → PR作成(Bash)
- Claude Code Action: `anthropics/claude-code-action@v1`
- `claude_args`: `--model claude-sonnet-4-6 --max-turns 30 --allowedTools Read,Edit,Glob,Grep`
- インラインプロンプト: 約65行（5ステップの分析手順 + プライバシールール + 出力フォーマット）
- DYNAMIC_CAREER 対象: 2社（株式会社Medii、株式会社and.d）

### 現在の問題
- max-turns 30 に到達してエラー終了
- permission denials 3件（Bash等の未許可ツール使用試行）
- コスト $2.10/実行

### .claude/ の状態
- `.claude/commands/` ディレクトリは未作成
- `.claude/skills/` ディレクトリは未作成
- `settings.local.json` に `Skill(spec-flow:build)` の参照が1件あるが、外部スキル

## 調査結果

### Claude Code スキルの定義方法

**配置場所**: `.claude/skills/<skill-name>/SKILL.md`（プロジェクトスキル）
- GitHub Actions では `actions/checkout` でリポジトリと一緒に取得されるため、プロジェクトスキルが必須

**SKILL.md フォーマット**:
```yaml
---
name: skill-name
description: スキルの説明（最大1024文字）
allowed-tools: Read, Edit, Glob, Grep
---
（Markdown 本文: 指示内容）
```

**主要フロントマターフィールド**:

| フィールド | 説明 |
|---|---|
| `name` | スラッシュコマンド名（英小文字・数字・ハイフン、最大64文字） |
| `description` | 自動発動の判断基準（最大1024文字） |
| `allowed-tools` | 承認なしで使えるツール |
| `disable-model-invocation` | `true` で自動呼び出し禁止（手動のみ） |
| `context` | `fork` でサブエージェントとして独立実行 |

**引数**: `$ARGUMENTS` プレースホルダーで受取可能
**動的コンテキスト**: `!`command`` 構文でシェルコマンドの出力を事前注入可能

出典: [Extend Claude with skills - Claude Code Docs](https://code.claude.com/docs/en/skills)

### claude-code-action でのスキル実行方法

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "/generate-dynamic-career"
    claude_args: "--model claude-sonnet-4-6 --max-turns 30 --allowedTools Read,Edit,Glob,Grep"
```

`prompt` にスラッシュコマンド形式でスキル名を指定するだけ。

出典: [Claude Code GitHub Actions - Claude Code Docs](https://code.claude.com/docs/en/github-actions)

### allowedTools の2レイヤー

1. **スキルの `allowed-tools`**: スキル実行中に承認なしで使えるツール
2. **`claude_args` の `--allowedTools`**: アクション全体の許可ツール（上位制約）

両方で許可されていないと使用できない。

### スキルのベストプラクティス

- SKILL.md は500行以下推奨（超える場合は別ファイルに分割）
- 詳細リファレンスは同ディレクトリの別ファイルに切り出し（プログレッシブディスクロージャー）
- スキルディレクトリに参考ファイルを同梱可能

```
generate-dynamic-career/
├── SKILL.md              # メイン指示
├── career-example.html   # 出力フォーマットの参考（または参照パス指定）
└── privacy-rules.md      # プライバシールールの詳細（CLAUDE.md から抜粋）
```

出典: [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

### スキル化で max-turns 問題を解決するアプローチ

1. **スキル内でデータ前処理を指示**: `data/github-data.json` から対象 Org のPRだけを事前抽出するよう指示し、無駄なデータ読み込みを減らす
2. **`!`command`` で動的コンテキスト注入**: スキル実行前に Bash でデータを前処理し、結果をスキルに埋め込む
3. **max-turns を増やす**: 50〜60 に変更
4. **プロンプトの簡潔化**: 5ステップを3ステップに統合

## 推奨・結論

### 推奨構成

```
.claude/skills/generate-dynamic-career/
├── SKILL.md           # メイン指示（現在のプロンプト65行をスキル化）
```

SKILL.md には:
- `name: generate-dynamic-career`
- `description`: DYNAMIC_CAREER プレースホルダーを GitHub データで置換する
- `allowed-tools: Read, Edit, Glob, Grep`
- 本文: 現在のプロンプト内容を移植 + 最適化

### ワークフロー側の変更

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "/generate-dynamic-career"
    claude_args: "--model claude-sonnet-4-6 --max-turns 50 --allowedTools Read,Edit,Glob,Grep"
```

### 追加の改善案

- max-turns を 50 に増加
- データ前処理ステップを Bash で追加（対象 Org の PR データのみ抽出した軽量 JSON を生成）

## 次のステップ

1. `/spec skill-based-profile-update` で実装仕様を策定
2. `.claude/skills/generate-dynamic-career/SKILL.md` を作成
3. `update-profile.yml` を簡素化
4. `workflow_dispatch` で動作テスト
