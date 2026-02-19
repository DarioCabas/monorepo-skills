#!/usr/bin/env bash
# create-skill.sh — Scaffolds a new skill from the canonical template
#
# Usage:
#   ./scripts/create-skill.sh react-native rn-animations
#   ./scripts/create-skill.sh angular ng-forms
#   ./scripts/create-skill.sh generic my-skill

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

TECH="${1:-}"
NAME="${2:-}"
TEMPLATE="skills/generic/skill-creator/assets/SKILL-TEMPLATE.md"

if [[ -z "$TECH" || -z "$NAME" ]]; then
  echo -e "${BOLD}Usage:${NC} ./scripts/create-skill.sh <technology> <skill-name>"
  echo ""
  echo "  Technologies: react-native | angular | generic"
  echo "  Examples:"
  echo "    ./scripts/create-skill.sh react-native rn-animations"
  echo "    ./scripts/create-skill.sh angular ng-forms"
  exit 1
fi

if [[ ! "$TECH" =~ ^(react-native|angular|generic)$ ]]; then
  echo -e "${RED}✗${NC} Unknown technology '$TECH'"
  echo "  Valid: react-native | angular | generic"
  exit 1
fi

if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo -e "${RED}✗${NC} Invalid name '$NAME'"
  echo "  Must match: ^[a-z0-9]+(-[a-z0-9]+)*\$"
  exit 1
fi

if [[ ${#NAME} -gt 64 ]]; then
  echo -e "${RED}✗${NC} Name too long (${#NAME} chars, max 64)"
  exit 1
fi

DEST="skills/$TECH/$NAME"

if [[ -d "$DEST" ]]; then
  echo -e "${YELLOW}⚠${NC}  '$DEST' already exists."
  read -r -p "  Overwrite? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

mkdir -p "$DEST"
cp "$TEMPLATE" "$DEST/SKILL.md"

# Replace placeholders
sed -i.bak \
  -e "s/^name: skill-name$/name: $NAME/" \
  -e "s/scope: react-native$/scope: $TECH/" \
  "$DEST/SKILL.md"
rm -f "$DEST/SKILL.md.bak"

echo ""
echo -e "${GREEN}✓${NC} Created ${BOLD}$DEST/SKILL.md${NC}"
echo ""
echo -e "  Fill in before using:"
echo -e "  ${BOLD}description:${NC} replace placeholder text with one descriptive line"
echo -e "  ${BOLD}metadata.scope:${NC} already set to '$TECH'"
echo ""
echo -e "  Then validate:"
echo -e "  ${BOLD}./scripts/validate-skills.sh $DEST/SKILL.md${NC}"
echo ""

if command -v code &>/dev/null; then
  code "$DEST/SKILL.md"
elif command -v cursor &>/dev/null; then
  cursor "$DEST/SKILL.md"
fi