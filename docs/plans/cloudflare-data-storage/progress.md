---
title: GitHub データの Cloudflare R2 移行
feature-name: cloudflare-data-storage
status: not-started
created: 2026-03-08
updated: 2026-03-08
---

# GitHub データの Cloudflare R2 移行 - 進捗管理

## 0. 関連情報

### リポジトリ

| 名前 | パス | 説明 |
|------|------|------|
| 884js | `/Users/yukihayashi/Desktop/mywork/884js` | Bash ベース、package.json なし |

### 関連ドキュメント

- `CLAUDE.md` - プロジェクト指示書
- `docs/plans/cloudflare-data-storage/research.md` - R2 選定の調査結果

## 1. タスク進捗

| # | タスク | 対象ファイル | 見積 | PR | リスク | 状態 |
|---|--------|-------------|------|-----|--------|------|
| T1 | cache restore ステップを R2 get に置換 + R2 バケット作成ステップ追加（バケットはワークフロー内で自動作成。事前作成不要） | `.github/workflows/update-deploy-profile.yml` | S | - | - | ✓ |
| T2 | cache save ステップを R2 put に置換（`if: always()` 維持） | `.github/workflows/update-deploy-profile.yml` | S | - | - | ✓ |
| T3 | CLAUDE.md のワークフロー説明を更新（R2 利用について追記） | `CLAUDE.md` | S | - | - | ✓ |
| T4 | CLOUDFLARE_API_TOKEN の権限確認: R2 read/write に加え、バケット作成（`r2 bucket create`）にも権限が必要 | - (手動) | 手動 | - | - | - |
| T5 | `workflow_dispatch` で手動実行して動作確認 | - (手動) | 手動 | - | - | - |

## 2. デリバリープラン

分割なし（1 PR）

全5タスクを単一PRで実装・マージする。タスク間の依存関係は plan.md のタスク依存グラフに従い、以下の順序で実装する:

1. T1: cache restore を R2 get に置換 + バケット作成ステップ追加
2. T2: cache save を R2 put に置換（T1 完了後）
3. T3: CLAUDE.md 更新（T2 完了後）
4. T4: API トークン権限確認・追加（T3 完了後）
5. T5: 手動実行で E2E 動作確認（T4 完了後）

## 3. 現在の状況

T1-T3 完了。コード変更は全て完了。T4（API トークン権限確認）と T5（手動実行テスト）は手動タスク。

## 4. 次にやること

T4: CLOUDFLARE_API_TOKEN に R2 read/write + バケット作成権限があるか確認。必要に応じて Cloudflare ダッシュボードで権限を追加する。
