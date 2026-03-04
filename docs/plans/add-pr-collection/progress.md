---
title: コミット廃止・マージ済みPR取得への切り替え
feature-name: add-pr-collection
status: in-progress
created: 2026-03-04
updated: 2026-03-04
---

# コミット廃止・マージ済みPR取得への切り替え - 進捗管理

## 1. タスク進捗

| # | タスク | 対象ファイル | 見積 | PR | リスク | 状態 |
|---|--------|-------------|------|-----|--------|------|
| 1 | recent_activity 関連コードの削除 | `scripts/collect-github-data.sh` | S | - | - | ✓ |
| 2 | コミット取得関連コードの削除（`fetch_my_commits`, `merge_commits`, `get_cached_commits`, ステップ6のループ、サマリー） | `scripts/collect-github-data.sh` | S | - | - | ✓ |
| 3 | `fetch_my_merged_prs()` ヘルパー関数の追加（ページネーション、author/merged_at フィルタ、差分更新、body 含む） | `scripts/collect-github-data.sh` | M | - | - | ✓ |
| 4 | `merge_prs()` ヘルパー関数の追加（number でデデュプ、merged_at 降順ソート） | `scripts/collect-github-data.sh` | S | - | - | ✓ |
| 5 | `get_cached_prs()` ヘルパー関数の追加 | `scripts/collect-github-data.sh` | S | - | - | ✓ |
| 6 | 個人リポジトリのPR取得ループ追加 | `scripts/collect-github-data.sh` | M | - | - | ✓ |
| 7 | Org リポジトリのPR取得ループ追加 | `scripts/collect-github-data.sh` | M | - | - | ✓ |
| 8 | サマリー出力にマージ済みPR数を追加 | `scripts/collect-github-data.sh` | S | - | - | ✓ |
| 9 | PRデータの活用方法・プライバシールール追記 | `CLAUDE.md` | S | - | - | ✓ |
| 10 | Stats セクションの総コミット数をマージ済みPR数に置き換え | `templates/readme-template.md` | S | - | - | ✓ |

## 2. デリバリープラン

分割なし（1 PR）

全10タスクを単一PRで実装・マージする。タスク間の依存関係は plan.md のタスク依存グラフに従い、以下の順序で実装する:

1. 独立タスク（並行実施可能）: #1, #2, #3, #4, #5, #9, #10
2. 依存タスク: #6, #7（#3, #4, #5 完了後）
3. 最終タスク: #8（#6, #7 完了後）

## 3. 現在の状況

全タスク実装完了。ビルド確認待ち。

## 4. 次にやること

スクリプトの動作確認（Step 3: ビルド確認）を実施する。
