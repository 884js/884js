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
MAX_PARALLEL=5

mkdir -p "$DATA_DIR"

# 一時ディレクトリ（スクリプト終了時に自動削除）
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# API コールカウンター
api_calls=0

echo "=== GitHub データ収集開始 ==="

# --- キャッシュデータ読み込み ---
cached_data_file="$tmp_dir/cached_data.json"
if [ -f "$OUTPUT_FILE" ]; then
  cp "$OUTPUT_FILE" "$cached_data_file"
  echo "  前回データ検出: 差分更新モード"
else
  echo '{}' > "$cached_data_file"
  echo "  前回データなし: フル取得モード"
fi

# --- ヘルパー: キャッシュからリポのマージ済みPRを取得 ---
# 引数: repo_name section(personal_repos|org_repos) output_file
get_cached_prs() {
  local repo_name="$1"
  local section="$2"
  local output_file="$3"
  jq --arg name "$repo_name" --arg section "$section" \
    '.[$section] // [] | map(select(.name == $name)) | .[0].my_merged_prs // []' \
    "$cached_data_file" > "$output_file" 2>/dev/null || echo '[]' > "$output_file"
}

# --- ヘルパー: 1リポのマージ済みPRをGraphQLで取得（並列実行対応） ---
# 引数: owner repo since_date output_file job_id
# job_id で一時ファイルを分離し、並列実行時の衝突を回避
fetch_my_merged_prs() {
  local owner="$1"
  local repo="$2"
  local since="${3:-}"
  local output_file="$4"
  local job_id="$5"
  local raw_file="$tmp_dir/gql_${job_id}_raw.json"
  local filtered_file="$tmp_dir/gql_${job_id}_filtered.json"
  local page_result_file="$tmp_dir/gql_${job_id}_page.json"
  local cursor=""

  local graphql_query='
    query($owner: String!, $repo: String!, $cursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequests(first: 100, states: MERGED, orderBy: {field: UPDATED_AT, direction: DESC}, after: $cursor) {
          nodes {
            number title body mergedAt updatedAt additions deletions changedFiles
            author { login }
            labels(first: 10) { nodes { name } }
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  '

  echo '[]' > "$output_file"

  while true; do
    local -a gh_args=(graphql -f "owner=$owner" -f "repo=$repo")
    if [ -n "$cursor" ]; then
      gh_args+=(-f "cursor=$cursor")
    fi
    gh_args+=(-f "query=$graphql_query")

    gh api "${gh_args[@]}" > "$raw_file" 2>/dev/null || { echo '[]' > "$output_file"; return; }
    # API コールをファイルに記録（並列実行時はシェル変数を更新できないため）
    echo 1 >> "$tmp_dir/api_calls_${job_id}.log"

    if jq -e '.errors // empty' "$raw_file" > /dev/null 2>&1; then break; fi
    if jq -e '.data.repository == null' "$raw_file" > /dev/null 2>&1; then break; fi

    local node_count
    node_count=$(jq '.data.repository.pullRequests.nodes | length' "$raw_file")

    # 差分更新: 末尾の updatedAt が since より古ければ打ち切り
    if [ -n "$since" ] && [ "$node_count" -gt 0 ]; then
      local oldest_updated
      oldest_updated=$(jq -r '.data.repository.pullRequests.nodes[-1].updatedAt // empty' "$raw_file")
      if [ -n "$oldest_updated" ] && [[ "$oldest_updated" < "$since" ]]; then
        jq --arg user "$GITHUB_USER" --arg since "$since" '
          [.data.repository.pullRequests.nodes[] |
           select(.author != null and .author.login == $user and .updatedAt >= $since) |
           { number, title, body: ((.body // "") | gsub("[\\u0000-\\u001f]"; "")),
             merged_at: .mergedAt, additions, deletions, changed_files: .changedFiles,
             labels: [.labels.nodes[].name] }]
        ' "$raw_file" > "$filtered_file"
        if [ "$(jq 'length' "$filtered_file")" -gt 0 ]; then
          jq -s 'add' "$output_file" "$filtered_file" > "$page_result_file"
          mv "$page_result_file" "$output_file"
        fi
        break
      fi
    fi

    # author フィルタ + フォーマット変換
    jq --arg user "$GITHUB_USER" '
      [.data.repository.pullRequests.nodes[] |
       select(.author != null and .author.login == $user) |
       { number, title, body: ((.body // "") | gsub("[\\u0000-\\u001f]"; "")),
         merged_at: .mergedAt, additions, deletions, changed_files: .changedFiles,
         labels: [.labels.nodes[].name] }]
    ' "$raw_file" > "$filtered_file"

    if [ "$(jq 'length' "$filtered_file")" -gt 0 ]; then
      jq -s 'add' "$output_file" "$filtered_file" > "$page_result_file"
      mv "$page_result_file" "$output_file"
    fi

    local has_next
    has_next=$(jq -r '.data.repository.pullRequests.pageInfo.hasNextPage' "$raw_file")
    if [ "$has_next" != "true" ]; then break; fi

    cursor=$(jq -r '.data.repository.pullRequests.pageInfo.endCursor' "$raw_file")
  done
}

# --- 1. ユーザープロフィール ---
echo "[1/6] ユーザープロフィール取得中..."
user_profile=$(gh api "users/$GITHUB_USER" 2>/dev/null) || user_profile='{}'
api_calls=$((api_calls + 1))

# --- 2. 個人 Public リポジトリ一覧 ---
echo "[2/6] 個人リポジトリ一覧取得中..."
personal_repos=$(gh repo list "$GITHUB_USER" \
  --source \
  --no-archived \
  --json name,description,url,primaryLanguage,stargazerCount,forkCount,updatedAt,repositoryTopics,isPrivate,isFork \
  --limit 100 2>/dev/null) || personal_repos='[]'
api_calls=$((api_calls + 1))

# --- 3. Org リポジトリ一覧 (gh api で自動取得) ---
echo "[3/6] Org リポジトリ取得中..."
org_repos="[]"

orgs=$(gh api user/orgs --jq '.[].login' 2>/dev/null) || orgs=""
api_calls=$((api_calls + 1))
if [ -n "$orgs" ]; then
  for org in $orgs; do
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
  echo "  所属 Org なし - Orgデータ収集をスキップ"
fi

# --- 4. 言語統計 (個人リポジトリ - 並列) ---
echo "[4/6] 個人リポジトリ言語統計取得中..."

personal_langs_dir="$tmp_dir/personal_langs"
mkdir -p "$personal_langs_dir"

repo_names=$(echo "$personal_repos" | jq -r '.[].name' 2>/dev/null || true)
idx=0
for repo in $repo_names; do
  (gh api "repos/$GITHUB_USER/$repo/languages" > "$personal_langs_dir/$idx.json" 2>/dev/null || echo '{}' > "$personal_langs_dir/$idx.json") &
  idx=$((idx + 1))
  if (( idx % MAX_PARALLEL == 0 )); then wait; fi
done
wait

api_calls=$((api_calls + idx))

if ls "$personal_langs_dir"/*.json 1>/dev/null 2>&1; then
  language_stats=$(jq -s '
    reduce .[] as $item ({};
      reduce ($item | keys[]) as $key (.;
        .[$key] = (.[$key] // 0) + $item[$key]
      )
    )
  ' "$personal_langs_dir"/*.json)
else
  language_stats="{}"
fi
echo "  個人リポ言語数: $(echo "$language_stats" | jq 'keys | length')"

# --- 5. 言語統計 (Org リポジトリ - 並列) ---
echo "[5/6] Org リポジトリ言語統計取得中..."

if [ "$(echo "$org_repos" | jq 'length')" -gt 0 ]; then
  org_langs_dir="$tmp_dir/org_langs"
  mkdir -p "$org_langs_dir"

  org_repo_entries=$(echo "$org_repos" | jq -r '.[] | "\(.org)/\(.name)"' 2>/dev/null || true)
  idx=0
  for entry in $org_repo_entries; do
    (gh api "repos/$entry/languages" > "$org_langs_dir/$idx.json" 2>/dev/null || echo '{}' > "$org_langs_dir/$idx.json") &
    idx=$((idx + 1))
    if (( idx % MAX_PARALLEL == 0 )); then wait; fi
  done
  wait

  api_calls=$((api_calls + idx))

  if ls "$org_langs_dir"/*.json 1>/dev/null 2>&1; then
    org_language_stats=$(jq -s '
      reduce .[] as $item ({};
        reduce ($item | keys[]) as $key (.;
          .[$key] = (.[$key] // 0) + $item[$key]
        )
      )
    ' "$org_langs_dir"/*.json)
  else
    org_language_stats="{}"
  fi
  echo "  Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
else
  org_language_stats="{}"
  echo "  スキップ（Org リポジトリなし）"
fi

# --- 6. マージ済みPR取得 (Org リポジトリ - 並列GraphQL) ---
echo "[6/6] Org リポジトリのマージ済みPR取得中..."

org_repos_file="$tmp_dir/org_repos_wip.json"
echo "$org_repos" > "$org_repos_file"

if [ "$(jq 'length' "$org_repos_file")" -gt 0 ]; then
  org_repo_count=$(jq 'length' "$org_repos_file")

  # 全リポのキャッシュ情報を事前収集
  for i in $(seq 0 $((org_repo_count - 1))); do
    repo_name=$(jq -r ".[$i].name" "$org_repos_file")
    get_cached_prs "$repo_name" "org_repos" "$tmp_dir/cached_prs_$i.json"
  done

  # 並列で GraphQL 取得（MAX_PARALLEL 件ずつ）
  for i in $(seq 0 $((org_repo_count - 1))); do
    org_name=$(jq -r ".[$i].org" "$org_repos_file")
    repo_name=$(jq -r ".[$i].name" "$org_repos_file")
    cached_prs_file="$tmp_dir/cached_prs_$i.json"
    since_date=$(jq -r '.[0].merged_at // empty' "$cached_prs_file" 2>/dev/null || echo '')

    echo "    - $org_name/$repo_name"

    (
      fetch_my_merged_prs "$org_name" "$repo_name" "$since_date" "$tmp_dir/fetched_prs_$i.json" "$i"
    ) &

    # MAX_PARALLEL 件ごとに wait
    if (( (i + 1) % MAX_PARALLEL == 0 )); then wait; fi
  done
  wait

  # 並列ジョブの API コール数を集計
  parallel_calls=$(cat "$tmp_dir"/api_calls_*.log 2>/dev/null | wc -l | tr -d ' ')
  api_calls=$((api_calls + parallel_calls))

  # 結果を順番に処理（キャッシュマージ + org_repos_file 更新）
  for i in $(seq 0 $((org_repo_count - 1))); do
    cached_prs_file="$tmp_dir/cached_prs_$i.json"
    fetched_prs_file="$tmp_dir/fetched_prs_$i.json"
    merged_prs_file="$tmp_dir/merged_prs_$i.json"

    since_date=$(jq -r '.[0].merged_at // empty' "$cached_prs_file" 2>/dev/null || echo '')

    if [ -n "$since_date" ]; then
      jq -s 'add | unique_by(.number) | sort_by(.merged_at) | reverse' \
        "$fetched_prs_file" "$cached_prs_file" > "$merged_prs_file"
    else
      cp "$fetched_prs_file" "$merged_prs_file"
    fi

    pr_count=$(jq 'length' "$merged_prs_file")
    echo "      $(jq -r ".[$i].name" "$org_repos_file"): マージ済みPR $pr_count 件"

    jq --argjson idx "$i" --slurpfile prs "$merged_prs_file" '
      .[$idx] += {my_merged_prs: $prs[0]}
    ' "$org_repos_file" > "$tmp_dir/org_repos_updated.json"
    mv "$tmp_dir/org_repos_updated.json" "$org_repos_file"
  done
else
  echo "  スキップ（Org リポジトリなし）"
fi

# --- JSON出力 ---
echo "=== データ結合・出力 ==="

# 各データを一時ファイルに書き出し、--slurpfile で読み込む（引数長制限を回避）
echo "$user_profile" > "$tmp_dir/profile.json"
echo "$personal_repos" > "$tmp_dir/personal_repos.json"
cp "$org_repos_file" "$tmp_dir/org_repos.json"
echo "$language_stats" > "$tmp_dir/language_stats.json"
echo "$org_language_stats" > "$tmp_dir/org_language_stats.json"
jq -n \
  --slurpfile profile "$tmp_dir/profile.json" \
  --slurpfile personal_repos "$tmp_dir/personal_repos.json" \
  --slurpfile org_repos "$tmp_dir/org_repos.json" \
  --slurpfile language_stats "$tmp_dir/language_stats.json" \
  --slurpfile org_language_stats "$tmp_dir/org_language_stats.json" \
  '{
    collected_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    profile: $profile[0],
    personal_repos: $personal_repos[0],
    org_repos: $org_repos[0],
    language_stats: $language_stats[0],
    org_language_stats: $org_language_stats[0]
  }' > "$OUTPUT_FILE"

# --- サマリー ---
total_prs=$(jq '[.[].my_merged_prs // [] | length] | add // 0' "$org_repos_file")

echo ""
echo "=== 完了: $OUTPUT_FILE ==="
echo "個人リポジトリ: $(echo "$personal_repos" | jq 'length') 件"
echo "Orgリポジトリ: $(jq 'length' "$org_repos_file") 件"
echo "個人リポ言語数: $(echo "$language_stats" | jq 'keys | length')"
echo "Org リポ言語数: $(echo "$org_language_stats" | jq 'keys | length')"
echo "マージ済みPR数: $total_prs 件"
echo "API コール数: $api_calls 回"
