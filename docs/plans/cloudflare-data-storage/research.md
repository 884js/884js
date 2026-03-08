# リサーチ: career.yml / github-data.json を Cloudflare ストレージに移行する是非

調査日: 2026-03-08
調査タイプ: 複合

## 調査ゴール
career.yml や github-data.json を Cloudflare の DB/ストレージ（D1, KV, R2）に保持するのが適切かどうかを判断する。

## 現状

### データファイル

| ファイル | サイズ | 管理方法 | 用途 |
|---------|--------|---------|------|
| career.yml | 9 KB | git 管理（手動編集） | 職務経歴のマスターデータ |
| data/github-data.json | 227 KB | .gitignore + GitHub Actions cache | GitHub API 収集データ（PR 149件含む） |

### 現在のキャッシュ戦略
- `actions/cache` で `data/` を保持（キー: `github-data-{run_id}`）
- スクリプト内で24時間以内の再実行はスキップ
- 離脱済み Org データはキャッシュから自動復元

## 調査結果

### Cloudflare ストレージ比較

| 観点 | KV | D1 (SQLite) | R2 (Object Storage) |
|------|-----|-------------|---------------------|
| データモデル | Key-Value | リレーショナル (SQL) | オブジェクト (ファイル) |
| 最大サイズ | 25 MiB/値 | 2 MB/行 | 実質無制限 |
| 整合性 | 結果整合性（数十秒遅延あり） | 強整合性 | 強整合性 |
| クエリ能力 | キーのみ | SQL | キーのみ |
| 無料枠 | 読100K/日, 書1K/日, 1GB | 読25M行/月, 書50K行/月, 500MB/DB | 10GB/月, PUT 1M/月, GET 10M/月 |
| wrangler CLI | `kv key put/get` | `d1 execute` | `r2 object put/get` |
| wrangler.toml 不要 | `--namespace-id` で可 | 事実上必要（バグ報告あり） | `--remote` で可 |

### GitHub Actions cache vs Cloudflare R2

| 観点 | GitHub Actions cache | Cloudflare R2 |
|------|---------------------|---------------|
| セットアップ | actions/cache だけ | wrangler + API トークン |
| データ保持期間 | 7日間未アクセスで自動削除 | 永続 |
| 上限 | 10 GB/リポジトリ | 10 GB/月（無料枠） |
| 外部アクセス | 不可 | Public URL / Workers 経由で可能 |
| 信頼性 | キャッシュミスでデータなし | 確実に取得可能 |

### ユースケース別の判断

**career.yml → git 管理を継続（移行不要）**
- 手動編集ファイル。変更履歴が重要
- DB に入れるメリットがない

**github-data.json → R2 が最適（移行メリットあり）**
- ファイルをそのまま put/get するだけで操作が自然
- actions/cache の「7日間ルール」によるデータ消失リスクがなくなる
- 強整合性で確実にデータを取得可能
- 週1回の更新なら無料枠で十分

## 推奨・結論

**career.yml**: 現状維持（git 管理）
**github-data.json**: **Cloudflare R2 への移行を推奨**

ただし、現状の actions/cache も週次実行なら7日ルールに引っかかりにくく、実用上は問題ない。R2 移行は「安定性向上」のための改善であり、必須ではない。

移行する場合のワークフロー変更イメージ:
```yaml
# キャッシュ復元の代わりに R2 から取得
- uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    command: r2 object get 884js-data/github-data.json --file ./data/github-data.json
  continue-on-error: true  # 初回はファイルなし

# ... データ収集・サイト生成・デプロイ ...

# キャッシュ保存の代わりに R2 にアップロード
- uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    command: r2 object put 884js-data/github-data.json --file ./data/github-data.json --content-type application/json
```

## 次のステップ
- R2 移行する場合 → `/spec cloudflare-data-storage` で仕様作成
- 現状維持で問題なし → 調査完了
