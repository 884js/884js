#!/usr/bin/env bash
# JSON → HTML 変換スクリプト
# data/career-json/{key}.json を読み込み、HTML を生成して
# dist/index.html の <!-- DYNAMIC_CAREER:会社名 --> プレースホルダーを置換する
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CAREER_JSON_DIR="$ROOT_DIR/data/career-json"
DIST_HTML="$ROOT_DIR/dist/index.html"

if [ ! -f "$DIST_HTML" ]; then
  echo "Error: dist/index.html not found" >&2
  exit 1
fi

# 会社キー → 会社名（連想配列を使わず順序配列で管理）
KEYS=("medii" "andd")
NAMES=("株式会社Medii" "株式会社and.d")

render_company_json() {
  local json_file="$1"

  if [ ! -f "$json_file" ]; then
    return
  fi

  local project_count
  project_count=$(jq '.projects | length' "$json_file")

  if [ "$project_count" -eq 0 ]; then
    return
  fi

  for ((i=0; i<project_count; i++)); do
    local name period summary
    name=$(jq -r ".projects[$i].name" "$json_file")
    period=$(jq -r ".projects[$i].period // \"\"" "$json_file")
    summary=$(jq -r ".projects[$i].summary // \"\"" "$json_file")

    echo ""
    echo "          <div class=\"career-project\">"
    echo "            <h4>${name}</h4>"
    echo "            <div class=\"project-meta\">"

    if [ -n "$period" ]; then
      echo "              <span class=\"project-period\">${period}</span>"
    fi

    echo "            </div>"

    # tech tags
    local tech_count
    tech_count=$(jq ".projects[$i].tech | length" "$json_file")
    if [ "$tech_count" -gt 0 ]; then
      echo "            <div class=\"project-tech\">"
      for ((t=0; t<tech_count; t++)); do
        local tech
        tech=$(jq -r ".projects[$i].tech[$t]" "$json_file")
        echo "              <span class=\"skill-tag\">${tech}</span>"
      done
      echo "            </div>"
    fi

    if [ -n "$summary" ]; then
      echo "            <p class=\"project-summary\">${summary}</p>"
    fi

    # achievements
    local ach_count
    ach_count=$(jq ".projects[$i].achievements | length" "$json_file")
    if [ "$ach_count" -gt 0 ]; then
      echo "            <ul class=\"project-achievements\">"
      for ((a=0; a<ach_count; a++)); do
        local achievement
        achievement=$(jq -r ".projects[$i].achievements[$a]" "$json_file")
        echo "              <li>${achievement}</li>"
      done
      echo "            </ul>"
    fi

    echo "          </div>"
  done
}

# 各会社の JSON を HTML に変換し、プレースホルダーを置換
for idx in "${!KEYS[@]}"; do
  KEY="${KEYS[$idx]}"
  COMPANY_NAME="${NAMES[$idx]}"
  PLACEHOLDER="<!-- DYNAMIC_CAREER:${COMPANY_NAME} -->"

  if ! grep -q "$PLACEHOLDER" "$DIST_HTML"; then
    echo "  $KEY: placeholder not found in dist/index.html, skipping"
    continue
  fi

  JSON_FILE="$CAREER_JSON_DIR/${KEY}.json"
  if [ ! -f "$JSON_FILE" ]; then
    echo "  $KEY: JSON not found, keeping placeholder"
    continue
  fi

  HTML_FRAGMENT=$(render_company_json "$JSON_FILE")

  if [ -z "$HTML_FRAGMENT" ]; then
    echo "  $KEY: no HTML generated, keeping placeholder"
    continue
  fi

  # プレースホルダーを HTML フラグメントで置換（awk で複数行対応）
  tmpfile=$(mktemp)
  echo "$HTML_FRAGMENT" > "$tmpfile"

  awk -v placeholder="$PLACEHOLDER" -v content_file="$tmpfile" '
    index($0, placeholder) {
      prefix = substr($0, 1, index($0, placeholder) - 1)
      suffix = substr($0, index($0, placeholder) + length(placeholder))
      if (prefix != "") printf "%s", prefix
      while ((getline line < content_file) > 0) print line
      close(content_file)
      if (suffix != "") print suffix
      next
    }
    { print }
  ' "$DIST_HTML" > "${DIST_HTML}.tmp" && mv "${DIST_HTML}.tmp" "$DIST_HTML"

  rm -f "$tmpfile"
  echo "  $KEY (${COMPANY_NAME}): replaced"
done

echo "=== render-career.sh 完了 ==="
