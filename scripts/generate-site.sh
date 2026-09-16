#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR/assets"
cp "$ROOT_DIR/templates/site/template.html" "$DIST_DIR/index.html"
cp "$ROOT_DIR/templates/site/styles.css" "$DIST_DIR/styles.css"
cp "$ROOT_DIR/templates/site/portfolio.js" "$DIST_DIR/portfolio.js"
cp "$ROOT_DIR/templates/site/assets/"* "$DIST_DIR/assets/"
echo "Generated dist/index.html"
