#!/usr/bin/env bash
# GitHub データ収集スクリプト
# gh CLI を使ってユーザー情報・リポジトリ情報を収集し、JSONで出力する
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
OUTPUT_FILE="$DATA_DIR/github-data.json"

GITHUB_USER="884js"

mkdir -p "$DATA_DIR"

echo "=== GitHub データ収集開始 ==="

# --- 1. ユーザープロフィール ---
echo "[1/5] ユーザープロフィール取得中..."
user_profile=$(gh api "users/$GITHUB_USER" 2>/dev/null || echo '{}')

# --- 2. 個人 Public リポジトリ一覧 ---
echo "[2/5] 個人リポジトリ一覧取得中..."
personal_repos=$(gh repo list "$GITHUB_USER" \
  --source \
  --no-archived \
  --json name,description,url,primaryLanguage,stargazerCount,forkCount,updatedAt,repositoryTopics,isPrivate,isFork \
  --limit 100 2>/dev/null || echo '[]')

# --- 3. Org リポジトリ一覧 (環境変数 GITHUB_ORGS から) ---
echo "[3/5] Org リポジトリ取得中..."
org_repos="[]"

if [ -n "${GITHUB_ORGS:-}" ]; then
  IFS=',' read -ra orgs <<< "$GITHUB_ORGS"
  for org in "${orgs[@]}"; do
    org=$(echo "$org" | xargs)  # trim whitespace
    [ -z "$org" ] && continue
    echo "  - Org: $org"
    repos=$(gh repo list "$org" \
      --no-archived \
      --json name,description,primaryLanguage,stargazerCount,forkCount,updatedAt,repositoryTopics,isPrivate,isFork \
      --limit 100 2>/dev/null || echo '[]')

    # 各リポジトリに org フィールドを追加
    repos_with_org=$(echo "$repos" | jq --arg org "$org" '[.[] | . + {org: $org}]')
    org_repos=$(echo "$org_repos $repos_with_org" | jq -s 'add')
  done
else
  echo "  GITHUB_ORGS 未設定 - Orgデータ収集をスキップ"
fi

# --- 4. 言語統計 (個人リポジトリ) ---
echo "[4/5] 言語統計取得中..."
language_stats="{}"

repo_names=$(echo "$personal_repos" | jq -r '.[].name' 2>/dev/null || true)
for repo in $repo_names; do
  langs=$(gh api "repos/$GITHUB_USER/$repo/languages" 2>/dev/null || echo '{}')
  language_stats=$(echo "$language_stats $langs" | jq -s '
    .[0] as $a | .[1] as $b |
    ($a | keys) + ($b | keys) | unique |
    reduce .[] as $key ({}; . + {($key): (($a[$key] // 0) + ($b[$key] // 0))})
  ')
done

# --- 5. 最近のアクティビティ ---
echo "[5/5] 最近のアクティビティ取得中..."
recent_activity=$(gh api "users/$GITHUB_USER/events/public" \
  --jq '[.[:20] | .[] | {type, repo: .repo.name, created_at}]' 2>/dev/null || echo '[]')

# --- JSON出力 ---
echo "=== データ結合・出力 ==="

jq -n \
  --argjson profile "$user_profile" \
  --argjson personal_repos "$personal_repos" \
  --argjson org_repos "$org_repos" \
  --argjson language_stats "$language_stats" \
  --argjson recent_activity "$recent_activity" \
  '{
    collected_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    profile: $profile,
    personal_repos: $personal_repos,
    org_repos: $org_repos,
    language_stats: $language_stats,
    recent_activity: $recent_activity
  }' > "$OUTPUT_FILE"

echo "=== 完了: $OUTPUT_FILE ==="
echo "個人リポジトリ: $(echo "$personal_repos" | jq 'length') 件"
echo "Orgリポジトリ: $(echo "$org_repos" | jq 'length') 件"
echo "言語数: $(echo "$language_stats" | jq 'keys | length')"
