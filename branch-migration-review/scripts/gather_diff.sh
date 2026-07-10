#!/usr/bin/env bash
# gather_diff.sh <base-branch> <branch>
#
# Verilen iki branch arasindaki diff'i toplar ve migration/config/seed/API
# kaliplarina uyan dosyalari on plana cikarir. Cikti, Claude'un daha detayli
# analiz yapmasi icin bir baslangic noktasidir - kesin hukum degildir.

set -euo pipefail

BASE="${1:-}"
BRANCH="${2:-}"

if [[ -z "$BASE" || -z "$BRANCH" ]]; then
  echo "Kullanim: gather_diff.sh <base-branch> <branch>" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "HATA: bu klasor bir git reposu degil." >&2
  exit 1
fi

# Branch'lerin var olup olmadigini kontrol et (local ya da origin/*)
resolve_ref() {
  local ref="$1"
  if git rev-parse --verify "$ref" >/dev/null 2>&1; then
    echo "$ref"
  elif git rev-parse --verify "origin/$ref" >/dev/null 2>&1; then
    echo "origin/$ref"
  else
    echo ""
  fi
}

# origin'den guncel veriyi cekmeyi dene, basarisiz olursa sessizce devam et
git fetch origin >/dev/null 2>&1 || true

BASE_REF="$(resolve_ref "$BASE")"
BRANCH_REF="$(resolve_ref "$BRANCH")"

if [[ -z "$BASE_REF" ]]; then
  echo "HATA: base branch bulunamadi: $BASE" >&2
  exit 1
fi
if [[ -z "$BRANCH_REF" ]]; then
  echo "HATA: branch bulunamadi: $BRANCH" >&2
  exit 1
fi

echo "=== BASE: $BASE_REF  |  BRANCH: $BRANCH_REF ==="
echo

echo "--- DEGISEN DOSYALAR (name-status) ---"
git diff --name-status "${BASE_REF}...${BRANCH_REF}"
echo

CHANGED_FILES="$(git diff --name-only "${BASE_REF}...${BRANCH_REF}")"

categorize() {
  local pattern="$1"
  local label="$2"
  local matches
  matches="$(echo "$CHANGED_FILES" | grep -E "$pattern" || true)"
  if [[ -n "$matches" ]]; then
    echo "[$label]"
    echo "$matches" | sed 's/^/  - /'
    echo
  fi
}

echo "--- KATEGORIZE EDILMIS SINYALLER ---"
categorize '(^|/)(migrations?|db/migrate|alembic/versions|prisma/migrations)/' "Migration dosyalari"
categorize '(^|/)models?\.py$|(^|/)models?/|(^|/)app/models|schema\.rb$|schema\.prisma$|(^|/)entities?/|Entity\.(ts|java)$|models?\.go$' "Model/entity dosyalari"
categorize '(^|/)(seed|fixtures?)' "Seed/fixture dosyalari"
categorize '(^|/)(config|settings|feature[_-]?flag)' "Config/settings ile ilgili dosyalar"
categorize '(^|/)(routes?|controllers?|api)/|views?\.py$|openapi|swagger|\.proto$|schema\.graphql$' "API/route/schema dosyalari"
echo

echo "--- TAM DIFF ---"
git diff "${BASE_REF}...${BRANCH_REF}"
