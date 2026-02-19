#!/usr/bin/env bash
# validate-skills.sh — Validates all SKILL.md files in the monorepo
#
# Usage:
#   ./scripts/validate-skills.sh               # validate all
#   ./scripts/validate-skills.sh skills/react-native/rn-no-rerenders/SKILL.md

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

check() {
  local file="$1"
  local errors=(); local warnings=()

  # Must start with ---
  if ! head -1 "$file" | grep -q "^---$"; then
    errors+=("Frontmatter must start on line 1 with ---")
  fi

  # Must close frontmatter
  if ! awk 'NR>1 && /^---$/{found=1;exit} END{exit !found}' "$file"; then
    errors+=("Frontmatter not closed with ---")
  fi

  local fm
  fm=$(awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm{print}' "$file")

  # name: required, regex ^[a-z0-9]+(-[a-z0-9]+)*$, max 64, must match folder
  if ! echo "$fm" | grep -qE "^name: [a-z0-9]+(-[a-z0-9]+)*$"; then
    errors+=("'name' missing or invalid — must match ^[a-z0-9]+(-[a-z0-9]+)*\$")
  else
    local name folder
    name=$(echo "$fm" | grep "^name:" | sed 's/name: //')
    folder=$(basename "$(dirname "$file")")
    [[ ${#name} -gt 64 ]] && errors+=("'name' exceeds 64 chars (${#name})")
    [[ "$folder" != "$name" ]] && errors+=("Folder '$folder' must match name '$name'")
  fi

  # description: required, min 80 chars, must have trigger clause
  # Note: block scalar (>) is valid YAML — allowed as long as indentation is consistent
  if ! echo "$fm" | grep -q "^description:"; then
    errors+=("'description' field missing")
  else
    # Extract description value — handles both single-line and block scalar (>)
    local desc
    if echo "$fm" | grep -qE "^description: *>"; then
      # Block scalar: join the indented lines into one string
      desc=$(awk '/^description:/{found=1;next} found && /^  /{printf "%s ", $0} found && !/^  /{exit}' <<< "$fm" | tr -s ' ')
    else
      desc=$(echo "$fm" | grep "^description:" | sed 's/^description: *//' | tr -d '"')
    fi
    [[ ${#desc} -lt 40 ]] && warnings+=("'description' is short — include what it does AND trigger conditions")
    echo "$desc" | grep -qi "trigger\|use when\|when user" || \
      warnings+=("'description' missing trigger clause — add 'Trigger: When ...'")
  fi

  # license: recommended
  echo "$fm" | grep -q "^license:" || warnings+=("'license' field missing (recommended: Apache-2.0)")

  # No H2 sections
  grep -q "^## " "$file" || warnings+=("No H2 sections found")

  # Print result
  local label
  label=$(basename "$(dirname "$file")")
  if [[ ${#errors[@]} -gt 0 ]]; then
    echo -e "${RED}✗${NC} ${BOLD}$label${NC}"
    for e in "${errors[@]}"; do echo -e "  ${RED}ERROR${NC} $e"; done
    for w in "${warnings[@]}"; do echo -e "  ${YELLOW}WARN${NC}  $w"; done
    ((FAIL++)) || true
  elif [[ ${#warnings[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} ${BOLD}$label${NC}"
    for w in "${warnings[@]}"; do echo -e "  ${YELLOW}WARN${NC}  $w"; done
    ((WARN++)) || true
  else
    echo -e "${GREEN}✓${NC} ${BOLD}$label${NC}"
    ((PASS++)) || true
  fi
}

echo -e "\n${BOLD}Validating skills...${NC}\n"

if [[ $# -gt 0 ]]; then
  check "$1"
else
  while IFS= read -r -d '' f; do check "$f"; done \
    < <(find skills -name "SKILL.md" -print0 | sort -z)
fi

echo -e "\n${GREEN}$PASS passed${NC} | ${YELLOW}$WARN warnings${NC} | ${RED}$FAIL failed${NC}\n"
[[ $FAIL -eq 0 ]]