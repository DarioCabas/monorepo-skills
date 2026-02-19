#!/usr/bin/env bash
# validate-skills.sh — Valida todos los SKILL.md del repo
#
# Uso:
#   bash scripts/validate-skills.sh                              # todos
#   bash scripts/validate-skills.sh skills/react-native/x/SKILL.md  # uno

if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; WARN=0

validate_file() {
  local file="$1"
  local errors=() warnings=()
  local skill tech
  skill=$(basename "$(dirname "$file")")
  tech=$(basename "$(dirname "$(dirname "$file")")")

  # frontmatter existe y cierra
  head -1 "$file" | grep -q "^---$" \
    || errors+=("frontmatter must start on line 1 with ---")
  awk 'NR>1 && /^---$/{found=1;exit} END{exit !found}' "$file" \
    || errors+=("frontmatter not closed with ---")

  local fm
  fm=$(awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm{print}' "$file")

  # name
  echo "$fm" | grep -qE "^name: [a-z0-9]+(-[a-z0-9]+)*$" \
    || errors+=("name: missing or invalid format (lowercase-with-hyphens)")
  local name; name=$(echo "$fm" | grep "^name:" | sed 's/name: //' || true)
  [[ -n "$name" && "$name" != "$skill" ]] \
    && errors+=("name '$name' must match folder '$skill'")

  # description
  echo "$fm" | grep -q "^description:" \
    || errors+=("description: field missing")
  local desc; desc=$(echo "$fm" | grep "^description:" | sed 's/^description: *//' || true)
  [[ -n "$desc" && ${#desc} -lt 20 ]] \
    && errors+=("description too short (${#desc} chars, min 20)")

  # scope — acepta `scope:` directo o `  scope:` bajo metadata:
  local scope tech_folder
  tech_folder=$(basename "$(dirname "$(dirname "$file")")")
  scope=$(echo "$fm" | grep -E "^\s*scope:" | sed 's/.*scope: *//' | tr -d ' ' | head -1 || true)
  [[ -z "$scope" ]] \
    && errors+=("scope: missing — add 'scope: $tech_folder'") \
    || { [[ "$scope" != "$tech_folder" ]] && errors+=("scope '$scope' must match folder '$tech_folder'"); }

  # trigger
  local has_trigger=false
  echo "$fm" | grep -qi "trigger" && has_trigger=true
  grep -qiE "^## (Trigger|When to Use)|^Trigger:" "$file" 2>/dev/null && has_trigger=true
  [[ "$has_trigger" == false ]] \
    && errors+=("missing trigger clause in description or body")

  # version (warning)
  echo "$fm" | grep -qE "^version: [0-9]+\.[0-9]+\.[0-9]+$" \
    || warnings+=("version: missing (recommended: 1.0.0)")

  # placeholders sin rellenar (warning)
  local ph; ph=$(grep -c "<!-- " "$file" 2>/dev/null || true)
  [[ $ph -gt 0 ]] && warnings+=("$ph placeholder(s) not filled in")

  # imprimir resultado
  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "$tech/$skill"
    for e in "${errors[@]}"; do printf "  error  %s\n" "$e"; done
    for w in "${warnings[@]}"; do printf "  warn   %s\n" "$w"; done
    ((FAIL++)) || true
  elif [[ ${#warnings[@]} -gt 0 ]]; then
    echo "$tech/$skill"
    for w in "${warnings[@]}"; do printf "  warn   %s\n" "$w"; done
    ((WARN++)) || true
  else
    echo "$tech/$skill  ok"
    ((PASS++)) || true
  fi
}

# correr
if [[ $# -gt 0 ]]; then
  validate_file "$1"
else
  while IFS= read -r -d '' f; do
    validate_file "$f"
  done < <(find "$REPO_DIR/skills" -name "SKILL.md" -print0 | sort -z)
fi

echo ""
echo "$PASS passed  $WARN warnings  $FAIL failed"
[[ $FAIL -eq 0 ]]