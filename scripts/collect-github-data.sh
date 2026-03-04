#!/usr/bin/env bash
# GitHub データ収集スクリプト
# gh CLI を使ってユーザー情報・リポジトリ情報を収集し、JSONで出力する
# 既存データがあれば差分更新（since パラメータ）で API コールを削減する
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
OUTPUT_FILE="$DATA_DIR/github-data.json"

GITHUB_USER="884js"

mkdir -p "$DATA_DIR"

# API コールカウンター
api_calls=0
new_commits=0

echo "=== GitHub データ収集開始 ==="

# --- キャッシュデータ読み込み ---
CACHED_DATA="{}"
if [ -f "$OUTPUT_FILE" ]; then
  CACHED_DATA=$(cat "$OUTPUT_FILE")
  echo "  前回データ検出: 差分更新モード"
else
  echo "  前回データなし: フル取得モード"
fi

# --- ヘルパー: キャッシュからリポのコミットを取得 ---
# 引数: repo_name section(personal_repos|org_repos)
get_cached_commits() {
  local repo_name="$1"
  local section="$2"
  echo "$CACHED_DATA" | jq --arg name "$repo_name" --arg section "$section" \
    '.[$section] // [] | map(select(.name == $name)) | .[0].my_commits // []' \
    2>/dev/null || echo '[]'
}

# --- ヘルパー: ページネーション付きコミット取得 ---
# 引数: owner repo [since_date]
# 出力: my_commits JSON配列
fetch_my_commits() {
  local owner="$1"
  local repo="$2"
  local since="${3:-}"
  local page=1
  local all_commits="[]"

  while true; do
    local url="repos/$owner/$repo/commits?author=$GITHUB_USER&per_page=100&page=$page"
    if [ -n "$since" ]; then
      url="${url}&since=$since"
    fi

    local response
    response=$(gh api "$url" \
      --jq '[.[] | {sha: .sha[0:7], message: (.commit.message | split("\n")[0]), date: .commit.author.date}]' 2>/dev/null) || response='[]'
    api_calls=$((api_calls + 1))

    local count
    count=$(echo "$response" | jq 'length')

    if [ "$count" -eq 0 ]; then
      break
    fi

    all_commits=$(echo "$all_commits $response" | jq -s 'add')
    new_commits=$((new_commits + count))

    if [ "$count" -lt 100 ]; then
      break
    fi

    page=$((page + 1))
  done

  echo "$all_commits"
}

# --- ヘルパー: 新規コミットとキャッシュをマージ ---
# 引数: new_commits cached_commits
# 出力: マージ済み JSON配列（sha で重複排除、日付降順）
merge_commits() {
  local new="$1"
  local cached="$2"
  echo "$new $cached" | jq -s 'add | unique_by(.sha) | sort_by(.date) | reverse'
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
user_profile=$(gh api "users/$GITHUB_USER" 2>/dev/null) || user_profile='{}'
api_calls=$((api_calls + 1))

# --- 2. 個人 Public リポジトリ一覧 ---
echo "[2/7] 個人リポジトリ一覧取得中..."
personal_repos=$(gh repo list "$GITHUB_USER" \
  --source \
  --no-archived \
  --json name,description,url,primaryLanguage,stargazerCount,forkCount,updatedAt,repositoryTopics,isPrivate,isFork \
  --limit 100 2>/dev/null) || personal_repos='[]'
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
      --limit 100 2>/dev/null) || repos='[]'
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
  langs=$(gh api "repos/$GITHUB_USER/$repo/languages" 2>/dev/null) || langs='{}'
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
    langs=$(gh api "repos/$entry/languages" 2>/dev/null) || langs='{}'
    api_calls=$((api_calls + 1))
    org_language_stats=$(merge_language_stats "$org_language_stats" "$langs")
  done
  echo "  Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
else
  echo "  スキップ（GITHUB_ORGS 未設定）"
fi

# --- 6. 全リポの自分のコミット一覧（差分更新対応） ---
echo "[6/7] コミット履歴取得中..."

# 6a. 個人リポジトリのコミット
echo "  個人リポジトリのコミット取得中..."
for repo in $repo_names; do
  echo "    - $GITHUB_USER/$repo"

  # キャッシュからの既存コミットと最新日付を取得
  cached_commits=$(get_cached_commits "$repo" "personal_repos")
  since_date=$(echo "$cached_commits" | jq -r '.[0].date // empty' 2>/dev/null || echo '')

  if [ -n "$since_date" ]; then
    echo "      差分取得 (since: $since_date)"
  fi

  fetched=$(fetch_my_commits "$GITHUB_USER" "$repo" "$since_date")

  # マージ: 新規 + キャッシュ（差分モード時のみ）
  if [ -n "$since_date" ]; then
    commits=$(merge_commits "$fetched" "$cached_commits")
  else
    commits="$fetched"
  fi

  commit_count=$(echo "$commits" | jq 'length')
  echo "      コミット数: $commit_count"

  # 元のリポ情報に my_commits を追加
  personal_repos=$(echo "$personal_repos" | jq --arg name "$repo" --argjson commits "$commits" '
    [.[] | if .name == $name then . + {my_commits: $commits} else . end]
  ')
done

# 6b. Org リポジトリのコミット
if [ -n "${GITHUB_ORGS:-}" ]; then
  echo "  Org リポジトリのコミット取得中..."
  org_repo_count=$(echo "$org_repos" | jq 'length')
  for i in $(seq 0 $((org_repo_count - 1))); do
    org=$(echo "$org_repos" | jq -r ".[$i].org")
    repo=$(echo "$org_repos" | jq -r ".[$i].name")
    echo "    - $org/$repo"

    cached_commits=$(get_cached_commits "$repo" "org_repos")
    since_date=$(echo "$cached_commits" | jq -r '.[0].date // empty' 2>/dev/null || echo '')

    if [ -n "$since_date" ]; then
      echo "      差分取得 (since: $since_date)"
    fi

    fetched=$(fetch_my_commits "$org" "$repo" "$since_date")

    if [ -n "$since_date" ]; then
      commits=$(merge_commits "$fetched" "$cached_commits")
    else
      commits="$fetched"
    fi

    commit_count=$(echo "$commits" | jq 'length')
    echo "      コミット数: $commit_count"

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
  --jq '[.[:20] | .[] | {type, repo: .repo.name, created_at}]' 2>/dev/null) || recent_activity='[]'
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

# --- サマリー ---
total_commits=$(echo "$personal_repos" | jq '[.[].my_commits // [] | length] | add // 0')
org_total=$(echo "$org_repos" | jq '[.[].my_commits // [] | length] | add // 0')
total_commits=$((total_commits + org_total))

echo ""
echo "=== 完了: $OUTPUT_FILE ==="
echo "個人リポジトリ: $(echo "$personal_repos" | jq 'length') 件"
echo "Orgリポジトリ: $(echo "$org_repos" | jq 'length') 件"
echo "個人リポ言語数: $(echo "$language_stats" | jq 'keys | length')"
echo "Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
echo "総コミット数: $total_commits 件"
echo "今回新規取得: $new_commits 件"
echo "API コール数: $api_calls 回"
