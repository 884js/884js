#!/usr/bin/env bash
# 職務経歴書サイト生成スクリプト
# career.yml + github-data.json + template.html から dist/index.html を決定的に生成
# has_org: true かつ projects が空の会社は <!-- DYNAMIC_CAREER:会社名 --> プレースホルダーを挿入
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_HTML="$ROOT_DIR/templates/site/template.html"
TEMPLATE_CSS="$ROOT_DIR/templates/site/styles.css"
CAREER_YML="$ROOT_DIR/career.yml"
GITHUB_DATA="$ROOT_DIR/data/github-data.json"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_HTML="$DIST_DIR/index.html"

mkdir -p "$DIST_DIR"

# --- 依存チェック ---
for cmd in yq jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed." >&2
    exit 1
  fi
done

# --- CSS コピー ---
cp "$TEMPLATE_CSS" "$DIST_DIR/styles.css"

# --- テンプレート読み込み ---
HTML=$(cat "$TEMPLATE_HTML")

# ====================
# ヘッダー
# ====================
USER_NAME=$(yq -r '.profile.name' "$CAREER_YML")

if [ -f "$GITHUB_DATA" ]; then
  USER_AVATAR=$(jq -r '.profile.avatar_url' "$GITHUB_DATA")
  USER_BIO=$(jq -r '.profile.bio // ""' "$GITHUB_DATA")
else
  USER_AVATAR="https://github.com/884js.png"
  USER_BIO=""
fi

HTML="${HTML//\{\{USER_NAME\}\}/$USER_NAME}"
HTML="${HTML//\{\{USER_AVATAR\}\}/$USER_AVATAR}"
HTML="${HTML//\{\{USER_BIO\}\}/$USER_BIO}"

# ====================
# Summary セクション
# ====================
generate_summary() {
  local summary
  summary=$(yq -r '.profile.summary' "$CAREER_YML")

  cat <<SUMMARY_EOF
<div class="summary-text">
$(echo "$summary" | while IFS= read -r line; do
  [ -n "$line" ] && echo "        <p>$line</p>"
done)
      </div>
      <div class="strengths">
        <h3>得意領域</h3>
SUMMARY_EOF

  local count
  count=$(yq -r '.profile.strengths | length' "$CAREER_YML")
  for ((i=0; i<count; i++)); do
    local title detail
    title=$(yq -r ".profile.strengths[$i].title" "$CAREER_YML")
    detail=$(yq -r ".profile.strengths[$i].detail" "$CAREER_YML")
    cat <<ITEM_EOF
        <div class="strength-item">
          <strong>$title</strong>
          <p>$detail</p>
        </div>
ITEM_EOF
  done

  echo "      </div>"
}

SUMMARY_SECTION=$(generate_summary)

# ====================
# Skills セクション
# ====================
generate_skills() {
  local categories=("languages:言語" "frameworks:フレームワーク" "tools:ツール・インフラ" "practices:設計・プロセス" "devops:DevOps")

  for entry in "${categories[@]}"; do
    local key="${entry%%:*}"
    local label="${entry#*:}"
    local count
    count=$(yq -r ".skills.$key | length" "$CAREER_YML")
    [ "$count" -eq 0 ] && continue

    cat <<CAT_EOF
        <div class="skill-category">
          <h3>$label</h3>
          <div class="skill-tags">
CAT_EOF
    for ((i=0; i<count; i++)); do
      local skill
      skill=$(yq -r ".skills.${key}[$i]" "$CAREER_YML")
      echo "            <span class=\"skill-tag\">$skill</span>"
    done
    cat <<CAT_END_EOF
          </div>
        </div>
CAT_END_EOF
  done
}

SKILLS_SECTION=$(generate_skills)

# ====================
# Career セクション
# ====================
generate_career() {
  local company_count
  company_count=$(yq -r '.companies | length' "$CAREER_YML")

  for ((c=0; c<company_count; c++)); do
    local name period role business has_org project_count
    name=$(yq -r ".companies[$c].name" "$CAREER_YML")
    period=$(yq -r ".companies[$c].period" "$CAREER_YML")
    role=$(yq -r ".companies[$c].role" "$CAREER_YML")
    business=$(yq -r ".companies[$c].business" "$CAREER_YML")
    has_org=$(yq -r ".companies[$c].has_org" "$CAREER_YML")
    project_count=$(yq -r ".companies[$c].projects | length" "$CAREER_YML")

    cat <<COMPANY_EOF
        <div class="career-item">
          <h3>${name}</h3>
          <div class="career-period">${period}</div>
          <div class="career-role">${role}</div>
          <div class="career-business">【事業内容：${business}】</div>
COMPANY_EOF

    if [ "$has_org" = "true" ] && [ "$project_count" -eq 0 ]; then
      # 動的生成対象: プレースホルダーを挿入
      echo "          <!-- DYNAMIC_CAREER:$name -->"
    else
      # 静的生成: career.yml の projects をそのまま HTML 化
      for ((p=0; p<project_count; p++)); do
        generate_project "$c" "$p"
      done
    fi

    echo "        </div>"
  done
}

generate_project() {
  local c=$1 p=$2
  local pname psummary pperiod prole pteam
  pname=$(yq -r ".companies[$c].projects[$p].name" "$CAREER_YML")
  psummary=$(yq -r ".companies[$c].projects[$p].summary" "$CAREER_YML")
  pperiod=$(yq -r ".companies[$c].projects[$p].period // \"\"" "$CAREER_YML")
  prole=$(yq -r ".companies[$c].projects[$p].role // \"\"" "$CAREER_YML")
  pteam=$(yq -r ".companies[$c].projects[$p].team // \"\"" "$CAREER_YML")

  cat <<PROJ_EOF

          <div class="career-project">
            <h4>$pname</h4>
            <div class="project-meta">
PROJ_EOF

  [ -n "$pperiod" ] && echo "              <span class=\"project-period\">$pperiod</span>"
  [ -n "$prole" ] && echo "              <span class=\"project-role\">$prole</span>"
  [ -n "$pteam" ] && echo "              <span class=\"project-team\">$pteam</span>"

  echo "            </div>"

  # tech tags
  local tech_count
  tech_count=$(yq -r ".companies[$c].projects[$p].tech | length" "$CAREER_YML")
  if [ "$tech_count" -gt 0 ]; then
    echo "            <div class=\"project-tech\">"
    for ((t=0; t<tech_count; t++)); do
      local tech
      tech=$(yq -r ".companies[$c].projects[$p].tech[$t]" "$CAREER_YML")
      echo "              <span class=\"skill-tag\">$tech</span>"
    done
    echo "            </div>"
  fi

  echo "            <p class=\"project-summary\">$psummary</p>"

  # achievements
  local ach_count
  ach_count=$(yq -r ".companies[$c].projects[$p].achievements | length" "$CAREER_YML")
  if [ "$ach_count" -gt 0 ]; then
    echo "            <ul class=\"project-achievements\">"
    for ((a=0; a<ach_count; a++)); do
      local achievement
      achievement=$(yq -r ".companies[$c].projects[$p].achievements[$a]" "$CAREER_YML")
      echo "              <li>$achievement</li>"
    done
    echo "            </ul>"
  fi

  echo "          </div>"
}

CAREER_SECTION=$(generate_career)

# ====================
# Stats セクション
# ====================
generate_stats() {
  local total_prs=0 total_additions=0 public_repos=0

  if [ -f "$GITHUB_DATA" ]; then
    # マージ済みPR数（全 org_repos の my_merged_prs を合算）
    total_prs=$(jq '[.org_repos[] | select(has("my_merged_prs")) | .my_merged_prs | length] | add // 0' "$GITHUB_DATA")

    # コード貢献量（全PRの additions を合計）
    total_additions=$(jq '[.org_repos[] | select(has("my_merged_prs")) | .my_merged_prs[] | .additions // 0] | add // 0' "$GITHUB_DATA")

    # 公開リポジトリ数
    public_repos=$(jq '.profile.public_repos // 0' "$GITHUB_DATA")
  fi

  # エンジニア経験年数（career.yml の最古の会社の period から算出）
  local oldest_period
  oldest_period=$(yq -r '.companies[-1].period' "$CAREER_YML")
  local start_year
  start_year=$(echo "$oldest_period" | grep -oE '^[0-9]{4}')
  local current_year
  current_year=$(date +%Y)
  local experience_years=$(( current_year - start_year ))

  # additions をフォーマット（カンマ区切り）
  local formatted_additions
  if [ "$total_additions" -ge 1000 ]; then
    formatted_additions=$(printf "%'d" "$total_additions")
  else
    formatted_additions="$total_additions"
  fi

  cat <<STATS_EOF
        <div class="stat-card">
          <div class="stat-value">${total_prs}</div>
          <div class="stat-label">マージ済みPR数</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${formatted_additions}+</div>
          <div class="stat-label">コード貢献量（行）</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${public_repos}</div>
          <div class="stat-label">公開リポジトリ数</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${experience_years}年+</div>
          <div class="stat-label">エンジニア経験</div>
        </div>
STATS_EOF
}

STATS_SECTION=$(generate_stats)

# ====================
# 日付
# ====================
GENERATED_DATE=$(date +%Y-%m-%d)

# ====================
# プレースホルダー置換
# ====================
# sed で複数行の置換を行う（一時ファイル経由）
replace_placeholder() {
  local placeholder="$1"
  local content_file="$2"
  local target_file="$3"

  # awk で置換（複数行対応）
  awk -v placeholder="$placeholder" -v content_file="$content_file" '
    index($0, placeholder) {
      # プレースホルダーの前の部分を出力
      prefix = substr($0, 1, index($0, placeholder) - 1)
      suffix = substr($0, index($0, placeholder) + length(placeholder))
      if (prefix != "") printf "%s", prefix
      while ((getline line < content_file) > 0) print line
      close(content_file)
      if (suffix != "") print suffix
      next
    }
    { print }
  ' "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
}

# まずテンプレートを出力ファイルにコピー
echo "$HTML" > "$OUTPUT_HTML"

# 各セクションを一時ファイルに書き出して置換
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

echo "$SUMMARY_SECTION" > "$tmpdir/summary.html"
echo "$SKILLS_SECTION" > "$tmpdir/skills.html"
echo "$CAREER_SECTION" > "$tmpdir/career.html"
echo "$STATS_SECTION" > "$tmpdir/stats.html"

replace_placeholder "{{SUMMARY_SECTION}}" "$tmpdir/summary.html" "$OUTPUT_HTML"
replace_placeholder "{{SKILLS_SECTION}}" "$tmpdir/skills.html" "$OUTPUT_HTML"
replace_placeholder "{{CAREER_SECTION}}" "$tmpdir/career.html" "$OUTPUT_HTML"
replace_placeholder "{{STATS_SECTION}}" "$tmpdir/stats.html" "$OUTPUT_HTML"

# 単純な文字列置換（残りのプレースホルダー）
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|{{GENERATED_DATE}}|$GENERATED_DATE|g" "$OUTPUT_HTML"
else
  sed -i "s|{{GENERATED_DATE}}|$GENERATED_DATE|g" "$OUTPUT_HTML"
fi

echo "=== 生成完了 ==="
echo "  Output: $OUTPUT_HTML"
echo "  CSS:    $DIST_DIR/styles.css"

# DYNAMIC_CAREER プレースホルダーの確認
dynamic_count=$(grep -c 'DYNAMIC_CAREER:' "$OUTPUT_HTML" || true)
if [ "$dynamic_count" -gt 0 ]; then
  echo "  動的生成対象: ${dynamic_count} 件"
  grep -oP '(?<=DYNAMIC_CAREER:).*?(?= -->)' "$OUTPUT_HTML" 2>/dev/null || \
    grep -o 'DYNAMIC_CAREER:[^-]*' "$OUTPUT_HTML" | sed 's/DYNAMIC_CAREER://;s/ *$//'
fi
