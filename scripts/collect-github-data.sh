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

# API コールカウンター
api_calls=0
total_commits=0

echo "=== GitHub データ収集開始 ==="

# --- ヘルパー: ページネーション付きコミット取得 ---
# 引数: owner repo
# 出力: my_commits JSON配列
fetch_my_commits() {
  local owner="$1"
  local repo="$2"
  local page=1
  local all_commits="[]"

  while true; do
    local response
    response=$(gh api "repos/$owner/$repo/commits?author=$GITHUB_USER&per_page=100&page=$page" \
      --jq '[.[] | {sha: .sha[0:7], message: (.commit.message | split("\n")[0]), date: .commit.author.date}]' 2>/dev/null || echo '[]')
    api_calls=$((api_calls + 1))

    local count
    count=$(echo "$response" | jq 'length')

    if [ "$count" -eq 0 ]; then
      break
    fi

    all_commits=$(echo "$all_commits $response" | jq -s 'add')
    total_commits=$((total_commits + count))

    if [ "$count" -lt 100 ]; then
      break
    fi

    page=$((page + 1))
  done

  echo "$all_commits"
}

# --- ヘルパー: 言語統計マージ ---
merge_language_stats() {
  local current="$1"
  local new_langs="$2"
  echo "$current $new_langs" | jq -s '
    .[0] as $a | .[1] as $b |
    ($a | keys) + ($b | keys) | unique |
    reduce .[] as $key ({}; . + {($key): (($a[$key] // 0) + ($b[$key] // 0))})
  '
}

# --- 1. ユーザープロフィール ---
echo "[1/7] ユーザープロフィール取得中..."
user_profile=$(gh api "users/$GITHUB_USER" 2>/dev/null || echo '{}')
api_calls=$((api_calls + 1))

# --- 2. 個人 Public リポジトリ一覧 ---
echo "[2/7] 個人リポジトリ一覧取得中..."
personal_repos=$(gh repo list "$GITHUB_USER" \
  --source \
  --no-archived \
  --json name,description,url,primaryLanguage,stargazerCount,forkCount,updatedAt,repositoryTopics,isPrivate,isFork \
  --limit 100 2>/dev/null || echo '[]')
api_calls=$((api_calls + 1))

# --- 3. Org リポジトリ一覧 (環境変数 GITHUB_ORGS から) ---
echo "[3/7] Org リポジトリ取得中..."
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
    api_calls=$((api_calls + 1))

    # 各リポジトリに org フィールドを追加
    repos_with_org=$(echo "$repos" | jq --arg org "$org" '[.[] | . + {org: $org}]')
    org_repos=$(echo "$org_repos $repos_with_org" | jq -s 'add')
  done
else
  echo "  GITHUB_ORGS 未設定 - Orgデータ収集をスキップ"
fi

# --- 4. 言語統計 (個人リポジトリ) ---
echo "[4/7] 個人リポジトリ言語統計取得中..."
language_stats="{}"

repo_names=$(echo "$personal_repos" | jq -r '.[].name' 2>/dev/null || true)
for repo in $repo_names; do
  langs=$(gh api "repos/$GITHUB_USER/$repo/languages" 2>/dev/null || echo '{}')
  api_calls=$((api_calls + 1))
  language_stats=$(merge_language_stats "$language_stats" "$langs")
done
echo "  個人リポ言語数: $(echo "$language_stats" | jq 'keys | length')"

# --- 5. 言語統計 (Org リポジトリ) ---
echo "[5/7] Org リポジトリ言語統計取得中..."
org_language_stats="{}"

if [ -n "${GITHUB_ORGS:-}" ]; then
  org_repo_entries=$(echo "$org_repos" | jq -r '.[] | "\(.org)/\(.name)"' 2>/dev/null || true)
  for entry in $org_repo_entries; do
    langs=$(gh api "repos/$entry/languages" 2>/dev/null || echo '{}')
    api_calls=$((api_calls + 1))
    org_language_stats=$(merge_language_stats "$org_language_stats" "$langs")
  done
  echo "  Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
else
  echo "  スキップ（GITHUB_ORGS 未設定）"
fi

# --- 6. 全リポの自分のコミット一覧 ---
echo "[6/7] コミット履歴取得中..."

# 6a. 個人リポジトリのコミット
echo "  個人リポジトリのコミット取得中..."
personal_repos_with_commits="[]"
for repo in $repo_names; do
  echo "    - $GITHUB_USER/$repo"
  commits=$(fetch_my_commits "$GITHUB_USER" "$repo")
  commit_count=$(echo "$commits" | jq 'length')
  echo "      コミット数: $commit_count"
  # 元のリポ情報に my_commits を追加
  repo_json=$(echo "$personal_repos" | jq --arg name "$repo" --argjson commits "$commits" '
    [.[] | if .name == $name then . + {my_commits: $commits} else . end]
  ')
  personal_repos="$repo_json"
done

# 6b. Org リポジトリのコミット
if [ -n "${GITHUB_ORGS:-}" ]; then
  echo "  Org リポジトリのコミット取得中..."
  org_repo_count=$(echo "$org_repos" | jq 'length')
  for i in $(seq 0 $((org_repo_count - 1))); do
    org=$(echo "$org_repos" | jq -r ".[$i].org")
    repo=$(echo "$org_repos" | jq -r ".[$i].name")
    echo "    - $org/$repo"
    commits=$(fetch_my_commits "$org" "$repo")
    commit_count=$(echo "$commits" | jq 'length')
    echo "      コミット数: $commit_count"
    # org_repos の該当リポに my_commits を追加
    org_repos=$(echo "$org_repos" | jq --argjson idx "$i" --argjson commits "$commits" '
      .[$idx] += {my_commits: $commits}
    ')
  done
else
  echo "  スキップ（GITHUB_ORGS 未設定）"
fi

# --- 7. 最近のアクティビティ ---
echo "[7/7] 最近のアクティビティ取得中..."
recent_activity=$(gh api "users/$GITHUB_USER/events/public" \
  --jq '[.[:20] | .[] | {type, repo: .repo.name, created_at}]' 2>/dev/null || echo '[]')
api_calls=$((api_calls + 1))

# --- JSON出力 ---
echo "=== データ結合・出力 ==="

jq -n \
  --argjson profile "$user_profile" \
  --argjson personal_repos "$personal_repos" \
  --argjson org_repos "$org_repos" \
  --argjson language_stats "$language_stats" \
  --argjson org_language_stats "$org_language_stats" \
  --argjson recent_activity "$recent_activity" \
  '{
    collected_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    profile: $profile,
    personal_repos: $personal_repos,
    org_repos: $org_repos,
    language_stats: $language_stats,
    org_language_stats: $org_language_stats,
    recent_activity: $recent_activity
  }' > "$OUTPUT_FILE"

echo ""
echo "=== 完了: $OUTPUT_FILE ==="
echo "個人リポジトリ: $(echo "$personal_repos" | jq 'length') 件"
echo "Orgリポジトリ: $(echo "$org_repos" | jq 'length') 件"
echo "個人リポ言語数: $(echo "$language_stats" | jq 'keys | length')"
echo "Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
echo "取得コミット総数: $total_commits 件"
echo "API コール数: $api_calls 回"
