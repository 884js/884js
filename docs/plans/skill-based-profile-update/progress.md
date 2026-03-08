---
title: update-profile プロンプトのスキル化
feature-name: skill-based-profile-update
status: not-started
created: 2026-03-08
updated: 2026-03-08
---

# skill-based-profile-update 進捗管理

## 対象リポジトリ

| リポジトリ | パス | 説明 |
|-----------|------|------|
| 884js | `/Users/yukihayashi/Desktop/mywork/884js` | 職務経歴書サイト自動生成リポジトリ |

## 関連ドキュメント

| ドキュメント | パス |
|-------------|------|
| CLAUDE.md | `CLAUDE.md` |
| リサーチ | `docs/plans/skill-based-profile-update/research.md` |
| 設計書 | `docs/plans/skill-based-profile-update/plan.md` |

## タスク進捗

| # | タスク | 対象ファイル | 見積 | PR | リスク | 状態 |
|---|--------|------------|------|-----|--------|------|
| 1 | SKILL.md 作成（フロントマター + プロンプト本文の移植・最適化） | `.claude/skills/generate-dynamic-career/SKILL.md` | 30min | - | - | - |
| 2 | update-profile.yml の Claude Code Action 設定変更（prompt 簡素化 + max-turns 増加） | `.github/workflows/update-profile.yml` | 10min | - | - | - |
| 3 | workflow_dispatch で手動実行して動作確認 | - | 15min | - | - | - |

## デリバリープラン

分割なし（1 PR）

## 現在の状況

未着手。

## 次にやること

タスク 1 から順に実装を開始する。
