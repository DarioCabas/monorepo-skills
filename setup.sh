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

# ── Registry ───────────────────────────────────────────────────────────────────
# Agregar aquí cuando se cree un skill nuevo en el repo
REGISTRY=(
  "angular/ng-no-rerenders"
  "angular/ng-solid-dry-kiss"
  "generic/skill-creator"
  "react-native/rn-no-rerenders"
  "react-native/rn-solid-dry-kiss"
)

# ── Colors ─────────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
WHITE='\033[97m'

# ── Primitivos de UI — estilo Vercel ───────────────────────────────────────────
ask()     { echo -ne "  ${CYAN}?${RESET} ${BOLD}$1${RESET} "; }
confirm() { echo -e  "  ${GREEN}✓${RESET} ${BOLD}$1${RESET} ${GRAY}$2${RESET}"; }
skip()    { echo -e  "  ${GRAY}·${RESET} $1"; }
info()    { echo -e  "  ${GRAY}$1${RESET}"; }
bail()    { echo -e  "\n  ${RED}✗${RESET} $1\n"; exit 1; }
warn()    { echo -e  "  ${YELLOW}!${RESET} $1"; }
blank()   { echo ""; }

# ── read compatible con curl | bash ───────────────────────────────────────────
input() {
  local varname="$1"
  if [[ -t 0 ]]; then
    read -r "$varname"
  elif [[ -e /dev/tty ]]; then
    read -r "$varname" </dev/tty
  else
    read -r "$varname"
  fi
}

# ── Detectar modo ──────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
[[ -d "$SKILLS_SRC" ]] && MODE="local" || MODE="remote"

[[ "$MODE" == "remote" ]] && { command -v curl &>/dev/null || bail "curl is required."; }

# ── Helpers ────────────────────────────────────────────────────────────────────
get_description() {
  local tech="$1" skill="$2"
  if [[ "$MODE" == "local" ]]; then
    local f="$SKILLS_SRC/$tech/$skill/SKILL.md"
    [[ -f "$f" ]] || { echo ""; return; }
    awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
      sub(/^description: */,""); print; exit
    }' "$f" | cut -c1-55
  else
    curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" 2>/dev/null \
      | awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
          sub(/^description: */,""); print; exit
        }' | cut -c1-55
  fi
}

install_skill() {
  local tech="$1" skill="$2" dest_base="$3"
  local dest="$dest_base/$skill"
  if [[ "$MODE" == "local" ]]; then
    [[ -L "$dest" || -d "$dest" ]] && rm -rf "$dest"
    ln -s "$SKILLS_SRC/$tech/$skill" "$dest"
  else
    mkdir -p "$dest"
    curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" -o "$dest/SKILL.md" 2>/dev/null \
      || { warn "Failed to download $skill — skipped"; return; }
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# TUI — estilo Vercel
# ══════════════════════════════════════════════════════════════════════════════
clear
blank
echo -e "  ${BOLD}DEUNA Agent Skills${RESET}"
info "agentskills.io · OpenCode · Claude Code · Cursor"
blank

# ── Tecnología ─────────────────────────────────────────────────────────────────
# Extraer tecnologías únicas del registry
TECHS=()
for entry in "${REGISTRY[@]}"; do
  tech="${entry%%/*}"
  already=false
  for t in "${TECHS[@]+"${TECHS[@]}"}"; do [[ "$t" == "$tech" ]] && already=true && break; done
  [[ "$already" == false ]] && TECHS+=("$tech")
done

ask "Which technology?"
blank
i=1
for tech in "${TECHS[@]}"; do
  count=0
  for e in "${REGISTRY[@]}"; do [[ "${e%%/*}" == "$tech" ]] && ((count++)) || true; done
  echo -e "  ${GRAY}$i)${RESET}  $tech ${GRAY}($count skills)${RESET}"
  ((i++))
done
echo -e "  ${GRAY}a)${RESET}  All"
blank

SELECTED_TECHS=()
while true; do
  echo -ne "  ${GRAY}›${RESET} "
  input choice
  [[ -z "$choice" ]] && continue
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED_TECHS=("${TECHS[@]}"); break
  fi
  valid=true; temp=()
  old_ifs="$IFS"; IFS=','; parts=($choice); IFS="$old_ifs"
  for part in "${parts[@]+"${parts[@]}"}"; do
    part="${part// /}"
    if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part < i )); then
      temp+=("${TECHS[$((part-1))]}")
    else
      warn "Invalid option: '$part'"; valid=false; break
    fi
  done
  [[ "$valid" == true && ${#temp[@]} -gt 0 ]] && { SELECTED_TECHS=("${temp[@]}"); break; }
done

# Mostrar selección confirmada (igual que Vercel: reemplaza la pregunta visualmente)
label=$(IFS=', '; echo "${SELECTED_TECHS[*]}")
confirm "Technology" "$label"

# ── Skills ────────────────────────────────────────────────────────────────────
blank
# Filtrar registry por tecnologías seleccionadas
AVAILABLE=()
for entry in "${REGISTRY[@]}"; do
  tech="${entry%%/*}"
  for sel in "${SELECTED_TECHS[@]}"; do
    [[ "$tech" == "$sel" ]] && AVAILABLE+=("$entry") && break
  done
done

ask "Which skills?"
blank
i=1
for entry in "${AVAILABLE[@]}"; do
  tech="${entry%%/*}"; name="${entry##*/}"
  desc=$(get_description "$tech" "$name")
  echo -e "  ${GRAY}$i)${RESET}  ${WHITE}$name${RESET}  ${GRAY}$desc${RESET}"
  ((i++))
done
echo -e "  ${GRAY}a)${RESET}  All"
blank

SELECTED=()
while true; do
  echo -ne "  ${GRAY}›${RESET} "
  input choice
  [[ -z "$choice" ]] && continue
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    SELECTED=("${AVAILABLE[@]}"); break
  fi
  valid=true; temp=()
  old_ifs="$IFS"; IFS=','; parts=($choice); IFS="$old_ifs"
  for part in "${parts[@]+"${parts[@]}"}"; do
    part="${part// /}"
    if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part < i )); then
      temp+=("${AVAILABLE[$((part-1))]}")
    else
      warn "Invalid option: '$part'"; valid=false; break
    fi
  done
  [[ "$valid" == true && ${#temp[@]} -gt 0 ]] && { SELECTED=("${temp[@]}"); break; }
done

label=$(IFS=', '; names=(); for e in "${SELECTED[@]}"; do names+=("${e##*/}"); done; echo "${names[*]}")
confirm "Skills" "$label"

# ── Directorio destino ─────────────────────────────────────────────────────────
blank
DEFAULT_PROJECT="$(pwd)"
ask "Install in ${CYAN}$DEFAULT_PROJECT${RESET}${BOLD}? ${GRAY}[Y/n]${RESET}"
input use_default
use_default="${use_default:-Y}"

if [[ ! "$use_default" =~ ^[Yy]$ ]]; then
  blank
  ask "Project path"
  while true; do
    echo -ne "  ${GRAY}›${RESET} "
    input DEFAULT_PROJECT
    DEFAULT_PROJECT="${DEFAULT_PROJECT/#\~/$HOME}"
    [[ -d "$DEFAULT_PROJECT" ]] && break
    warn "Directory not found: $DEFAULT_PROJECT"
  done
fi

TARGET_DIR="$DEFAULT_PROJECT/.opencode/skills"
confirm "Target" "$TARGET_DIR"

# ── Instalar ───────────────────────────────────────────────────────────────────
blank
mkdir -p "$TARGET_DIR"

for entry in "${SELECTED[@]}"; do
  tech="${entry%%/*}"; skill="${entry##*/}"
  install_skill "$tech" "$skill" "$TARGET_DIR"
  confirm "Installed" "$skill"
done

# ── Done ───────────────────────────────────────────────────────────────────────
blank
echo -e "  ${GREEN}${BOLD}Done!${RESET} ${#SELECTED[@]} skill(s) added to your project."
blank
info "Restart OpenCode to load the new skills."
blank
if [[ "$MODE" == "remote" ]]; then
  info "To update: curl -fsSL $RAW_BASE/setup.sh | bash"
else
  info "To update: git pull in $REPO_DIR (symlinks update automatically)"
fi
blank