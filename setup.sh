#!/usr/bin/env bash
# setup.sh — DEUNA Agent Skills installer
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/DarioCabas/monorepo-skills/main/setup.sh | bash
#   ./setup.sh   (si tienes el repo clonado localmente)

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────────────────────
GITHUB_ORG="DarioCabas"
GITHUB_REPO="monorepo-skills"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_BRANCH"

# ── Registry de skills ─────────────────────────────────────────────────────────
# Formato: "tecnologia/skill-name"
# Agregar skills aquí cuando se creen nuevos en el repo
REGISTRY=(
  "angular/ng-no-rerenders"
  "angular/ng-solid-dry-kiss"
  "generic/skill-creator"
  "react-native/rn-no-rerenders"
  "react-native/rn-solid-dry-kiss"
)

# ── Colors ─────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

divider() { echo -e "${DIM}────────────────────────────────────────────${NC}"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }
success() { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()     { echo -e "  ${RED}✗${NC}  $1"; exit 1; }

# read que funciona tanto en modo normal como en curl | bash
ask() {
  local prompt="$1" varname="$2"
  if [[ -t 0 ]]; then
    # stdin es terminal normal
    read -r -p "$prompt" "$varname"
  elif [[ -e /dev/tty ]]; then
    # stdin ocupado por pipe (curl | bash) — leer del terminal directamente
    read -r -p "$prompt" "$varname" </dev/tty
  else
    # fallback para entornos sin /dev/tty
    read -r -p "$prompt" "$varname"
  fi
}

# ── Detectar modo: local (symlinks) o remoto (curl download) ───────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"

if [[ -d "$SKILLS_SRC" ]]; then
  MODE="local"
else
  MODE="remote"
  command -v curl &>/dev/null || err "curl is required. Install it and try again."
fi

# ── Helpers ────────────────────────────────────────────────────────────────────
get_description() {
  local tech="$1" skill="$2"
  if [[ "$MODE" == "local" ]]; then
    local f="$SKILLS_SRC/$tech/$skill/SKILL.md"
    [[ -f "$f" ]] || { echo "No description"; return; }
    awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
      sub(/^description: */,""); print; exit
    }' "$f" | cut -c1-60
  else
    curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" 2>/dev/null \
      | awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
          sub(/^description: */,""); print; exit
        }' | cut -c1-60
  fi
}

install_skill() {
  local tech="$1" skill="$2" dest_base="$3"
  local dest="$dest_base/$skill"
  if [[ "$MODE" == "local" ]]; then
    [[ -L "$dest" || -d "$dest" ]] && rm -rf "$dest"
    ln -s "$SKILLS_SRC/$tech/$skill" "$dest"
    success "Linked   ${BOLD}$skill${NC} ${DIM}→ symlink${NC}"
  else
    mkdir -p "$dest"
    if curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" -o "$dest/SKILL.md" 2>/dev/null; then
      success "Downloaded ${BOLD}$skill${NC}"
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
  echo -e "  ${DIM}Mode: local — skills will be symlinked${NC}"
else
  echo -e "  ${DIM}Mode: remote — skills will be downloaded from GitHub${NC}"
fi
echo ""
divider

# ── Step 1: Technology ─────────────────────────────────────────────────────────
header "Step 1 of 3 — Technology"
echo -e "  Which technology are you working with?\n"

# Extraer tecnologías únicas del registry
TECHS=()
for entry in "${REGISTRY[@]}"; do
  tech="${entry%%/*}"
  # Agregar solo si no está ya en el array
  local_found=false
  for t in "${TECHS[@]+"${TECHS[@]}"}"; do
    [[ "$t" == "$tech" ]] && local_found=true && break
  done
  [[ "$local_found" == false ]] && TECHS+=("$tech")
done

i=1
for tech in "${TECHS[@]}"; do
  count=0
  for entry in "${REGISTRY[@]}"; do
    [[ "${entry%%/*}" == "$tech" ]] && ((count++)) || true
  done
  echo -e "  ${CYAN}$i)${NC} ${BOLD}$tech${NC} ${DIM}($count skills)${NC}"
  ((i++))
done
echo -e "  ${CYAN}a)${NC} All technologies"
echo ""

SELECTED_TECHS=()
while true; do
  ask "  Choose [1-$((i-1)) or 'a']: " choice
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED_TECHS=("${TECHS[@]}"); break
  fi
  valid=true; temp=()
  old_ifs="$IFS"; IFS=','
  parts=($choice)
  IFS="$old_ifs"
  for part in "${parts[@]+"${parts[@]}"}"; do
    part="${part// /}"
    if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part < i )); then
      temp+=("${TECHS[$((part-1))]}")
    else
      warn "Invalid: '$part'"; valid=false; break
    fi
  done
  [[ "$valid" == true && ${#temp[@]} -gt 0 ]] && { SELECTED_TECHS=("${temp[@]}"); break; }
done

echo ""
for t in "${SELECTED_TECHS[@]}"; do success "$t"; done

# ── Step 2: Skills ─────────────────────────────────────────────────────────────
header "Step 2 of 3 — Skills"
echo -e "  Which skills do you want to install?\n"

# Filtrar registry por tecnologías seleccionadas
AVAILABLE=()
for entry in "${REGISTRY[@]}"; do
  tech="${entry%%/*}"
  for sel in "${SELECTED_TECHS[@]}"; do
    [[ "$tech" == "$sel" ]] && AVAILABLE+=("$entry") && break
  done
done

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
  ask "  Choose (number, comma-separated, or 'a'): " choice
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED=("${AVAILABLE[@]}"); break
  fi
  valid=true; temp=()
  old_ifs="$IFS"; IFS=','
  parts=($choice)
  IFS="$old_ifs"
  for part in "${parts[@]+"${parts[@]}"}"; do
    part="${part// /}"
    if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part < i )); then
      temp+=("${AVAILABLE[$((part-1))]}")
    else
      warn "Invalid: '$part'"; valid=false; break
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

ask "  Use this path? [Y/n]: " use_default
use_default="${use_default:-Y}"

if [[ ! "$use_default" =~ ^[Yy]$ ]]; then
  echo -e "\n  Enter the absolute path to your project:"
  echo -e "  ${DIM}Example: /Users/dario/projects/my-app${NC}\n"
  while true; do
    ask "  Path: " DEFAULT_PROJECT
    DEFAULT_PROJECT="${DEFAULT_PROJECT/#\~/$HOME}"
    [[ -d "$DEFAULT_PROJECT" ]] && break || warn "Directory not found: '$DEFAULT_PROJECT'"
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
echo -e "  Skills :"
for entry in "${SELECTED[@]}"; do
  echo -e "    ${GREEN}+${NC} ${entry##*/}"
done
echo ""

ask "  Confirm? [Y/n]: " confirm
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
  echo -e "  ${BOLD}To update:${NC} re-run this command"
  echo -e "  ${DIM}curl -fsSL $RAW_BASE/setup.sh | bash${NC}"
else
  echo -e "  ${BOLD}To update:${NC} git pull in $REPO_DIR"
  echo -e "  ${DIM}Symlinks update automatically.${NC}"
fi
echo ""
divider
echo ""