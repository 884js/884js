---
title: 職務経歴書サイトのモダンデザイン刷新 - 進捗管理
feature-name: modern-site-design
plan: docs/plans/modern-site-design/plan.md
created: 2026-03-07
updated: 2026-03-07
---

# 職務経歴書サイトのモダンデザイン刷新 - 進捗管理

## 対象リポジトリ

| リポジトリ | パス | 説明 |
|-----------|------|------|
| 884js | `/Users/yukihayashi/Desktop/mywork/884js` | 職務経歴書サイト自動生成リポジトリ |

## 関連ドキュメント

| ドキュメント | パス |
|-------------|------|
| CLAUDE.md | `CLAUDE.md` |
| デザインリサーチ | `docs/plans/modern-site-design/research.md` |

## タスク進捗

| # | タスク | 対象ファイル | 見積 | PR | リスク | 状態 |
|---|--------|-------------|------|-----|--------|------|
| 1 | カラースキーム変更（:root と light テーマのカスタムプロパティ更新、--glass-bg / --glass-border 追加） | `templates/site/styles.css` | S | - | - | ✓ |
| 2 | テンプレート HTML 構造変更（セクション順序を Summary → Skills → Career → Stats に変更 + nav 要素追加） | `templates/site/template.html` | S | - | - | ✓ |
| 3 | generate-site.sh のセクション順序対応（replace_placeholder の呼び出し順を Summary → Skills → Career → Stats に変更） | `scripts/generate-site.sh` | S | - | - | ✓ |
| 4 | Hero セクション CSS 改修（Mesh Gradient 背景 + gradient text + clip-path） | `templates/site/styles.css` | M | - | - | ✓ |
| 5 | ナビゲーション CSS（sticky nav + Glassmorphism 背景 + リンクスタイリング） | `templates/site/styles.css` | S | - | - | ✓ |
| 6 | Career タイムライン CSS（::before 縦ライン + ::after ドットマーカー + Glassmorphism カード） | `templates/site/styles.css` | M | - | - | ✓ |
| 7 | Skills セクション CSS 改修（.skill-tag ホバー時グロー効果 + border-color 変化） | `templates/site/styles.css` | S | - | - | ✓ |
| 8 | Stats Bento Grid CSS（4カラムグリッド + nth-child(1) span 2x2 + Glassmorphism + グロー数字） | `templates/site/styles.css` | M | - | - | ✓ |
| 9 | CSS 未定義クラスへのスタイル追加（.career-project, .project-*, .summary-text, .strengths, .strength-item, .career-business） | `templates/site/styles.css` | M | - | - | ✓ |
| 10 | スクロールフェードインアニメーション CSS（@keyframes fadeInUp + @supports (animation-timeline: view()) + フォールバック） | `templates/site/styles.css` | S | - | - | ✓ |
| 11 | レスポンシブ対応の調整（640px ブレークポイントで Stats 2col化、nav 折り返し、clip-path 解除、タイムライン縮小） | `templates/site/styles.css` | M | - | - | ✓ |
| 12 | サイト再生成（bash scripts/generate-site.sh）して dist/ の動作確認 | `dist/index.html`, `dist/styles.css` | S | - | - | ✓ |

## デリバリープラン

分割なし（1 PR）

## 現在の状況

全タスク完了。ブラウザでの手動検証待ち。

## 次にやること

ブラウザで dist/index.html を開いて目視確認 → 問題なければ PR 作成。
