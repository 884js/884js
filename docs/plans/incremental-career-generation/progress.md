---
title: 動的キャリア生成のインクリメンタル更新
feature-name: incremental-career-generation
status: in-progress
created: 2026-03-08
updated: 2026-03-08
---

# 動的キャリア生成のインクリメンタル更新 - 進捗管理

## 0. 関連情報

### リポジトリ

| 名前 | パス | 説明 |
|------|------|------|
| 884js | `/Users/yukihayashi/Desktop/mywork/884js` | Bash ベース、package.json なし |

### 関連ドキュメント

- `CLAUDE.md` - プロジェクト指示書
- `docs/plans/incremental-career-generation/research.md` - 差分更新方式の調査結果
- `docs/plans/cloudflare-data-storage/plan.md` - R2 基盤の設計

## 1. タスク進捗

| # | タスク | 対象ファイル | 見積 | PR | リスク | 状態 |
|---|--------|-------------|------|-----|--------|------|
| T1 | ワークフローにハッシュ計算・比較ステップを追加（R2 から前回ハッシュ・JSON 取得、jq + sha256sum でハッシュ計算、比較結果を output に設定） | `.github/workflows/update-deploy-profile.yml` | M | - | - | ✓ |
| T2 | Claude Code Action に if 条件追加（ハッシュ不一致時のみ実行）+ allowedTools を Read,Write,Glob,Grep に変更 | `.github/workflows/update-deploy-profile.yml` | S | - | - | ✓ |
| T3 | SKILL.md の出力を JSON に変更（出力先を data/career-json/{key}.json に変更、JSON フォーマット仕様を明記、差分更新モード指示追加、allowedTools 更新） | `.claude/skills/generate-dynamic-career/SKILL.md` | M | - | - | ✓ |
| T4 | render-career.sh を新規作成（data/career-json/ の JSON を読み込み、jq で HTML 生成、dist/index.html のプレースホルダーを置換） | `scripts/render-career.sh` | L | - | - | ✓ |
| T5 | ワークフローに render-career.sh 実行ステップ追加 + JSON・ハッシュの R2 保存ステップ追加 | `.github/workflows/update-deploy-profile.yml` | M | - | - | ✓ |
| T6 | CLAUDE.md の更新（JSON 出力方式と差分更新フローの説明追記） | `CLAUDE.md` | S | - | - | ✓ |

## 2. デリバリープラン

分割なし（1 PR）

全6タスクを単一PRで実装・マージする。タスク間の依存関係は plan.md のタスク依存グラフに従い、以下の順序で実装する:

1. T1: ハッシュ計算・比較ステップ追加
2. T2: Claude Code Action の条件付き実行 + allowedTools 変更（T1 完了後）
3. T3: SKILL.md JSON 出力変更（T2 完了後）
4. T4: render-career.sh 新規作成
5. T5: render 実行ステップ + R2 保存ステップ追加（T3, T4 完了後）
6. T6: CLAUDE.md 更新（T5 完了後）

## 3. 現在の状況

全タスク実装完了。ローカルテスト（render-career.sh）も通過。PR 作成待ち。

## 4. 次にやること

PR 作成 → workflow_dispatch で E2E テスト。
