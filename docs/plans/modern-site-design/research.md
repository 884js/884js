# リサーチ: 職務経歴書サイトのモダンデザイン改善

調査日: 2026-03-07
調査タイプ: 複合（コードベース + 外部技術）

## 調査ゴール
現在の GitHub ダークテーマ風のシンプルなデザインを、よりモダンで印象的なデザインに改善するための具体的なアプローチを明らかにする。

## 現状

- 静的 HTML + CSS のみ（JS なし）
- Inter + JetBrains Mono フォント
- GitHub ダークテーマ風カラー（ダーク/ライト対応）
- max-width: 900px の1カラム、カードベース
- アニメーションなし

## 調査結果

### デザインスタイル比較

| スタイル | 実装難易度 | ダークモード相性 | 印象 | CV向き |
|---|---|---|---|---|
| **Glassmorphism** | 中 | 高（要調整） | プレミアム・未来的 | 部分採用推奨 |
| **Neobrutalism** | 低 | 高 | 個性的・記憶に残る | 尖りすぎリスク |
| **Bento Grid** | 低〜中 | 高 | 整理・情報密度高 | Stats/Skills に最適 |
| **Minimal Dark** | 低 | 最高 | プロフェッショナル | 現状の延長で実現可能 |

### 参考サイト

| サイト | 注目点 |
|---|---|
| brittanychiang.com | Minimal dark、背景 `#11172a` + ティールアクセント |
| joshwcomeau.com | `#0d0f12` 背景 + ネオンマゼンタ |
| tim-gesemann.dev | タイムライン表現 |

### CSS のみで実現できるモダンエフェクト

**1. Mesh Gradient 背景（Hero）**
```css
background:
  radial-gradient(ellipse at 20% 50%, rgba(99, 102, 241, 0.3) 0%, transparent 60%),
  radial-gradient(ellipse at 80% 20%, rgba(34, 211, 238, 0.2) 0%, transparent 60%),
  #0d1117;
```

**2. グラデーションテキスト（見出し）**
```css
.gradient-text {
  background: linear-gradient(135deg, #22d3ee, #6366f1);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

**3. Glassmorphism カード**
```css
.glass-card {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
}
```
ブラウザサポート 97%超。blur は 8〜15px 推奨。

**4. CSS Scroll-Driven Animations**
```css
.career-item {
  animation: fadeInUp linear;
  animation-timeline: view();
  animation-range: entry 0% entry 40%;
}
```
Chrome 115+/Edge 115+ 対応。Firefox 未対応（フォールバック必要）。

**5. clip-path（Hero 下端を斜めにカット）**
```css
.hero { clip-path: polygon(0 0, 100% 0, 100% 88%, 0 100%); }
```

**6. グロー効果（Stats / Skills）**
```css
.stat-value { text-shadow: 0 0 20px rgba(88, 166, 255, 0.5); }
.skill-tag:hover { box-shadow: 0 0 16px rgba(34, 211, 238, 0.5); }
```

### カラーパレット候補

| パレット名 | 背景 | アクセント | テキスト |
|---|---|---|---|
| Tech & Futuristic | `#0F172A` | `#22D3EE` (ネオンシアン) | `#F1F5F9` |
| Deep Indigo | `#020617` | `#6366F1` (インディゴ) | `#E2E8F0` |
| Teal Dark (Brittany Chiang風) | `#11172A` | `#599692` (ティール) | `#CCD6F6` |

### フォントペアリング

現在の Inter + JetBrains Mono は優秀。差別化するなら見出しを Geist Sans（Vercel製）または Satoshi に変更。

### セクション別改善アイデア

**Hero**: Mesh Gradient 背景 + グラデーションテキスト名前 + clip-path 下端斜め
**Skills**: グロー効果ホバー + カテゴリ別グリッド
**Career**: 縦軸ライン + ドットマーカーのタイムライン（`::before`/`::after` 疑似要素）+ スクロールフェードイン
**Stats**: Bento Grid（重要な統計は大カード）+ グロー効果数字

### ブラウザ互換性

| 機能 | Chrome | Firefox | Safari |
|---|---|---|---|
| backdrop-filter | 76+ | 103+ | 9+ |
| animation-timeline | 115+ | 未対応 | 26+予定 |
| @property | 85+ | 未対応 | 16.4+ |
| CSS Grid / clip-path | 全対応 | 全対応 | 全対応 |

## 推奨・結論

**「Polished Minimal Dark」ベースに部分的に Bento Grid + Glassmorphism を導入** が最適。

- 職務経歴書は読みやすさが最重要。全面 Glassmorphism は可読性リスク
- Neobrutalism は採用担当者向けには「尖りすぎ」
- Bento Grid は Stats/Skills に限定適用
- Glassmorphism はカード背景にアクセント的に使用
- スクロールアニメーションは Chrome 系のみ拡張、Firefox は静的表示でフォールバック

## 次のステップ

1. カラーパレットの選定（Tech & Futuristic or Deep Indigo）
2. `/spec modern-site-design` で具体的な実装仕様を策定
3. セクション単位で段階的に適用
