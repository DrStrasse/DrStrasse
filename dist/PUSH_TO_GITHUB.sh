#!/usr/bin/env bash
# Запуск НА СВОЁМ ПК (где уже git login / gh / ssh)
set -euo pipefail
BUNDLE="${1:-push-cctv.bundle}"
REPO_URL="${REPO_URL:-https://github.com/DrStrasse/DrStrasse.git}"
BRANCH="arena/019f69c8-drstrasse"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --branch "$BRANCH" "$REPO_URL" "$TMP/repo"
cd "$TMP/repo"
git fetch "$BUNDLE"
# bundle has commits after origin tip
git reset --hard FETCH_HEAD 2>/dev/null || {
  # if fetch put refs differently
  git pull --ff-only || true
  git bundle unbundle "$BUNDLE"
  git reset --hard HEAD
}
# safer: get tip from bundle
TIP=$(git bundle list-heads "$BUNDLE" | awk '{print $1; exit}')
git fetch "$BUNDLE" "$TIP"
git reset --hard "$TIP"
git push origin "HEAD:$BRANCH"
echo "OK pushed $TIP -> origin/$BRANCH"
