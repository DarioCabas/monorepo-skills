#!/usr/bin/env bash
# setup.sh — DEUNA Agent Skills installer
#
# PUBLIC repo  → descarga solo los SKILL.md que eliges via curl (sin clonar)
# PRIVATE repo → usa symlinks si ya tienes el repo clonado localmente
#
# Uso público (sin clonar):
#   curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/monorepo-skills/main/setup.sh | bash
#
# Uso local (repo clonado):
#   ./setup.sh

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
GITHUB_ORG="DarioCabas"
GITHUB_REPO="monorepo-skills"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_BRANCH"
API_BASE="https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO"

# ── Colors ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

divider() { echo -e "${DIM}────────────────────────────────────────────${NC}"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }
success() { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()     { echo -e "  ${RED}✗${NC}  $1"; exit 1; }

# ── Detectar modo: local (symlinks) o remoto (curl download) ───────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"

if [[ -d "$SKILLS_SRC" ]]; then
  MODE="local"
else
  MODE="remote"
  command -v curl &>/dev/null || err "curl is required. Install it and try again."
fi

# ── Funciones de discovery ─────────────────────────────────────────────────────
list_technologies() {
  if [[ "$MODE" == "local" ]]; then
    find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d | sort | xargs -I{} basename {}
  else
    curl -fsSL "$API_BASE/contents/skills" 2>/dev/null \
      | grep '"name"' | sed 's/.*"name": *"\([^"]*\)".*/\1/' | grep -v '^\.'
  fi
}

list_skills_for_tech() {
  local tech="$1"
  if [[ "$MODE" == "local" ]]; then
    find "$SKILLS_SRC/$tech" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
      | sort | xargs -I{} basename {}
  else
    curl -fsSL "$API_BASE/contents/skills/$tech" 2>/dev/null \
      | grep '"name"' | sed 's/.*"name": *"\([^"]*\)".*/\1/' | grep -v '^\.'
  fi
}

get_description() {
  local tech="$1" skill="$2"
  local skill_file
  if [[ "$MODE" == "local" ]]; then
    skill_file="$SKILLS_SRC/$tech/$skill/SKILL.md"
    [[ -f "$skill_file" ]] || { echo "No description"; return; }
    awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
      sub(/^description: */,""); print; exit
    }' "$skill_file" | cut -c1-65
  else
    curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" 2>/dev/null \
      | awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
          sub(/^description: */,""); print; exit
        }' | cut -c1-65
  fi
}

# ── Instalar un skill ──────────────────────────────────────────────────────────
install_skill() {
  local tech="$1" skill="$2" dest_base="$3"
  local dest="$dest_base/$skill"

  if [[ "$MODE" == "local" ]]; then
    # Symlink — siempre apunta al original, se actualiza solo con git pull
    [[ -L "$dest" || -d "$dest" ]] && rm -rf "$dest"
    ln -s "$SKILLS_SRC/$tech/$skill" "$dest"
    success "Linked   ${BOLD}$skill${NC} ${DIM}→ (symlink)${NC}"
  else
    # Descarga solo el SKILL.md — sin clonar el repo completo
    mkdir -p "$dest"
    if curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" -o "$dest/SKILL.md" 2>/dev/null; then
      success "Downloaded ${BOLD}$skill${NC} ${DIM}→ $dest/SKILL.md${NC}"
    else
      warn "Failed to download $skill — skipped"
    fi
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# TUI
# ══════════════════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${BOLD}${CYAN}  DEUNA Agent Skills${NC}"
echo -e "${DIM}  agentskills.io · OpenCode · Claude Code · Cursor${NC}"
echo ""
divider
if [[ "$MODE" == "local" ]]; then
  echo -e "  ${DIM}Mode: local repo — skills will be symlinked${NC}"
else
  echo -e "  ${DIM}Mode: remote — skills will be downloaded from GitHub${NC}"
fi
echo ""
divider

# ── Step 1: Technology ─────────────────────────────────────────────────────────
header "Step 1 of 3 — Technology"

[[ "$MODE" == "remote" ]] && echo -e "  Fetching from GitHub...\n"

TECHS=()
while IFS= read -r t; do [[ -n "$t" ]] && TECHS+=("$t"); done < <(list_technologies)
[[ ${#TECHS[@]} -eq 0 ]] && err "No technologies found. Check connection or repo path."

i=1
for tech in "${TECHS[@]}"; do
  count=$(list_skills_for_tech "$tech" | wc -l | tr -d ' ')
  echo -e "  ${CYAN}$i)${NC} ${BOLD}$tech${NC} ${DIM}($count skills)${NC}"
  ((i++))
done
echo -e "  ${CYAN}a)${NC} All technologies"
echo ""

SELECTED_TECHS=()
while true; do
  read -r -p "  Choose [1-$((i-1)) or 'a']: " choice
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED_TECHS=("${TECHS[@]}"); break
  fi
  valid=true; temp=()
  IFS=',' read -ra picks <<< "$choice"
  for pick in "${picks[@]}"; do
    pick="${pick// /}"
    if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick < i )); then
      temp+=("${TECHS[$((pick-1))]}")
    else
      warn "Invalid: '$pick'"; valid=false; break
    fi
  done
  [[ "$valid" == true && ${#temp[@]} -gt 0 ]] && { SELECTED_TECHS=("${temp[@]}"); break; }
done

echo ""
for t in "${SELECTED_TECHS[@]}"; do success "$t"; done

# ── Step 2: Skills ─────────────────────────────────────────────────────────────
header "Step 2 of 3 — Skills"
echo -e "  Which skills do you want to install?\n"

AVAILABLE=()
for tech in "${SELECTED_TECHS[@]}"; do
  while IFS= read -r skill; do
    [[ -n "$skill" ]] && AVAILABLE+=("$tech/$skill")
  done < <(list_skills_for_tech "$tech")
done

[[ ${#AVAILABLE[@]} -eq 0 ]] && err "No skills found."

i=1
for entry in "${AVAILABLE[@]}"; do
  tech="${entry%%/*}"; name="${entry##*/}"
  desc=$(get_description "$tech" "$name")
  echo -e "  ${CYAN}$i)${NC} ${BOLD}$name${NC}"
  echo -e "     ${DIM}$tech${NC} — $desc"
  ((i++))
done
echo -e "  ${CYAN}a)${NC} All of the above"
echo ""

SELECTED=()
while true; do
  read -r -p "  Choose (number, comma-separated, or 'a'): " choice
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED=("${AVAILABLE[@]}"); break
  fi
  valid=true; temp=()
  IFS=',' read -ra picks <<< "$choice"
  for pick in "${picks[@]}"; do
    pick="${pick// /}"
    if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick < i )); then
      temp+=("${AVAILABLE[$((pick-1))]}")
    else
      warn "Invalid: '$pick'"; valid=false; break
    fi
  done
  [[ "$valid" == true && ${#temp[@]} -gt 0 ]] && { SELECTED=("${temp[@]}"); break; }
done

echo ""
for entry in "${SELECTED[@]}"; do success "${entry##*/}"; done

# ── Step 3: Destino ────────────────────────────────────────────────────────────
header "Step 3 of 3 — Target project"

DEFAULT_PROJECT="$(pwd)"
echo -e "  Detected: ${CYAN}$DEFAULT_PROJECT${NC}"
echo -e "  Skills → ${CYAN}$DEFAULT_PROJECT/.opencode/skills/${NC}"
echo ""
read -r -p "  Use this path? [Y/n]: " use_default
use_default="${use_default:-Y}"

if [[ ! "$use_default" =~ ^[Yy]$ ]]; then
  echo -e "\n  Enter the absolute path to your project:"
  echo -e "  ${DIM}Example: /Users/dario/projects/my-app${NC}\n"
  while true; do
    read -r -p "  Path: " DEFAULT_PROJECT
    DEFAULT_PROJECT="${DEFAULT_PROJECT/#\~/$HOME}"
    [[ -d "$DEFAULT_PROJECT" ]] && break || warn "Directory not found"
  done
fi

TARGET_DIR="$DEFAULT_PROJECT/.opencode/skills"

# ── Confirm ────────────────────────────────────────────────────────────────────
echo ""
divider
echo ""
echo -e "  ${BOLD}Ready to install${NC}\n"
if [[ "$MODE" == "remote" ]]; then
  echo -e "  Source : ${CYAN}github.com/$GITHUB_ORG/$GITHUB_REPO${NC}"
else
  echo -e "  Source : ${CYAN}$SKILLS_SRC${NC} ${DIM}(local)${NC}"
fi
echo -e "  Target : ${CYAN}$TARGET_DIR${NC}"
echo -e "  Mode   : ${CYAN}$MODE${NC}"
echo -e "  Skills :"
for entry in "${SELECTED[@]}"; do
  echo -e "    ${GREEN}+${NC} ${entry##*/}"
done
echo ""
read -r -p "  Confirm? [Y/n]: " confirm
confirm="${confirm:-Y}"
[[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "\n  Cancelled.\n"; exit 0; }

# ── Install ────────────────────────────────────────────────────────────────────
echo ""
mkdir -p "$TARGET_DIR"

for entry in "${SELECTED[@]}"; do
  tech="${entry%%/*}"; skill="${entry##*/}"
  install_skill "$tech" "$skill" "$TARGET_DIR"
done

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
divider
echo ""
echo -e "  ${GREEN}${BOLD}Done!${NC} ${#SELECTED[@]} skill(s) installed."
echo -e "  ${DIM}$TARGET_DIR${NC}"
echo ""
echo -e "  ${BOLD}Next:${NC} Restart OpenCode to load the skills."
echo ""
if [[ "$MODE" == "remote" ]]; then
  echo -e "  ${BOLD}To update:${NC} re-run this script"
  echo -e "  ${DIM}curl -fsSL $RAW_BASE/setup.sh | bash${NC}"
else
  echo -e "  ${BOLD}To update:${NC} git pull in $REPO_DIR"
  echo -e "  ${DIM}Symlinks update automatically.${NC}"
fi
echo ""
divider
echo ""