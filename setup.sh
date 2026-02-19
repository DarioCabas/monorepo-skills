#!/usr/bin/env bash
# setup.sh — DEUNA Agent Skills installer
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/DarioCabas/monorepo-skills/main/setup.sh | bash
#   ./setup.sh   (repo clonado localmente)

# Forzar bash — evita correr con sh/dash
if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi

set -euo pipefail

GITHUB_ORG="DarioCabas"
GITHUB_REPO="monorepo-skills"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_BRANCH"

# ── Colors ─────────────────────────────────────────────────────────────────────
R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
GRAY='\033[90m'; WHITE='\033[97m'

# ── Detectar modo ──────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
[[ -d "$SKILLS_SRC" ]] && MODE="local" || MODE="remote"
[[ "$MODE" == "remote" ]] && { command -v curl &>/dev/null || { echo "curl is required"; exit 1; }; }

# ── read compatible con curl | bash ───────────────────────────────────────────
_input() {
  if [[ -t 0 ]]; then read -r "$1"
  elif [[ -e /dev/tty ]]; then read -r "$1" </dev/tty
  else read -r "$1"; fi
}

_key() {
  if [[ -t 0 ]]; then IFS= read -r -s -n1 "$1" 2>/dev/null || true
  elif [[ -e /dev/tty ]]; then IFS= read -r -s -n1 "$1" </dev/tty 2>/dev/null || true
  else IFS= read -r -s -n1 "$1" 2>/dev/null || true; fi
}

# ── Timeline helpers ───────────────────────────────────────────────────────────
tl_pending() { echo -e "  ${GRAY}◇${R}  $1"; }
tl_done()    { echo -e "  ${GREEN}◆${R}  $1"; }
tl_info()    { echo -e "  ${GRAY}|  ${DIM}$1${R}"; }
tl_ask()     { echo -e "  ${YELLOW}◆${R}  ${BOLD}$1${R}"; }

# ── Registry ───────────────────────────────────────────────────────────────────
REGISTRY_TECHS=()
REGISTRY_NAMES=()
REGISTRY_DESCS=()

load_registry() {
  local json=""
  if [[ "$MODE" == "local" ]] && [[ -f "$REPO_DIR/registry.json" ]]; then
    json=$(cat "$REPO_DIR/registry.json")
  else
    json=$(curl -fsSL "$RAW_BASE/registry.json" 2>/dev/null) \
      || { echo -e "  ${R}✗  Could not load registry"; exit 1; }
  fi

  local parsed=""
  if command -v python3 &>/dev/null; then
    parsed=$(python3 - "$json" << 'PY'
import sys, json
for s in json.loads(sys.argv[1]).get("skills", []):
    print("{}\t{}\t{}".format(s["tech"], s["name"], s.get("description","")[:55].replace("\n"," ")))
PY
)
  elif command -v python &>/dev/null; then
    parsed=$(python - "$json" << 'PY'
import sys, json
for s in json.loads(sys.argv[1]).get("skills", []):
    print("{}\t{}\t{}".format(s["tech"], s["name"], s.get("description","")[:55].replace("\n"," ")))
PY
)
  fi

  while IFS=$'\t' read -r tech name desc; do
    [[ -n "$name" ]] || continue
    REGISTRY_TECHS+=("$tech")
    REGISTRY_NAMES+=("$name")
    REGISTRY_DESCS+=("$desc")
  done <<< "$parsed"
}

# ── Tecnologías únicas del registry ───────────────────────────────────────────
get_unique_techs() {
  local -a result=()
  local t already
  for t in "${REGISTRY_TECHS[@]}"; do
    already=false
    local x
    for x in "${result[@]+"${result[@]}"}"; do [[ "$x" == "$t" ]] && already=true && break; done
    [[ "$already" == false ]] && result+=("$t")
  done
  echo "${result[@]}"
}

# Skills filtradas por tecnología
get_skills_for_tech() {
  local tech="$1"
  local i
  FILTERED_NAMES=()
  FILTERED_DESCS=()
  for i in "${!REGISTRY_TECHS[@]}"; do
    [[ "${REGISTRY_TECHS[$i]}" == "$tech" ]] || continue
    FILTERED_NAMES+=("${REGISTRY_NAMES[$i]}")
    FILTERED_DESCS+=("${REGISTRY_DESCS[$i]}")
  done
}

# ── Instalar skill ─────────────────────────────────────────────────────────────
install_skill() {
  local tech="$1" skill="$2" dest_base="$3"
  local dest="$dest_base/$skill"
  if [[ "$MODE" == "local" ]]; then
    [[ -L "$dest" || -d "$dest" ]] && rm -rf "$dest"
    ln -s "$SKILLS_SRC/$tech/$skill" "$dest"
  else
    mkdir -p "$dest"
    curl -fsSL "$RAW_BASE/skills/$tech/$skill/SKILL.md" -o "$dest/SKILL.md" 2>/dev/null \
      || { echo -e "  ${YELLOW}!${R} Failed: $skill"; return; }
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# SELECTOR INTERACTIVO — genérico
# Parámetros: arrays ITEMS_NAMES y ITEMS_DESCS (globales antes de llamar)
# multi=true  → space para multi-selección
# multi=false → enter selecciona uno solo
# Resultado en: SEL_INDICES=()
# ══════════════════════════════════════════════════════════════════════════════
ITEMS_NAMES=()
ITEMS_DESCS=()
SEL_INDICES=()

run_selector() {
  local multi="${1:-true}"
  local total=${#ITEMS_NAMES[@]}
  local cursor=0
  local search=""
  SEL_INDICES=()

  local -a visible=()
  local menu_height=0

  _filter() {
    visible=()
    local i
    for i in "${!ITEMS_NAMES[@]}"; do
      if [[ -z "$search" ]] || echo "${ITEMS_NAMES[$i]} ${ITEMS_DESCS[$i]}" | grep -qi "$search" 2>/dev/null; then
        visible+=("$i")
      fi
    done
  }

  _is_sel() {
    local s
    for s in "${SEL_INDICES[@]+"${SEL_INDICES[@]}"}"; do [[ "$s" == "$1" ]] && return 0; done
    return 1
  }

  _toggle() {
    local idx="$1" found=false s; local new=()
    for s in "${SEL_INDICES[@]+"${SEL_INDICES[@]}"}"; do
      if [[ "$s" == "$idx" ]]; then found=true; else new+=("$s"); fi
    done
    [[ "$found" == true ]] && SEL_INDICES=("${new[@]+"${new[@]}"}") || SEL_INDICES+=("$idx")
  }

  _render() {
    _filter
    local vc=${#visible[@]}
    [[ $cursor -ge $vc && $vc -gt 0 ]] && cursor=$((vc - 1))

    if [[ $menu_height -gt 0 ]]; then
      local _i; for _i in $(seq 1 $menu_height); do printf '\033[1A\033[2K'; done
    fi

    local lines=0

    # Barra de búsqueda
    echo -e "  ${GRAY}Search:${R} ${WHITE}$search${R}${CYAN}▌${R}"
    if [[ "$multi" == "true" ]]; then
      echo -e "  ${GRAY}↑↓ move · space select · enter confirm · a all · type to filter${R}"
    else
      echo -e "  ${GRAY}↑↓ move · enter confirm · type to filter${R}"
    fi
    ((lines+=2))

    local vi orig name desc box
    for vi in "${!visible[@]}"; do
      orig=${visible[$vi]}
      name="${ITEMS_NAMES[$orig]}"
      desc="${ITEMS_DESCS[$orig]}"

      if [[ "$multi" == "true" ]]; then
        _is_sel "$orig" && box="${GREEN}◆${R}" || box="${GRAY}◇${R}"
        if [[ $vi -eq $cursor ]]; then
          echo -e "  ${CYAN}›${R} $box ${WHITE}${BOLD}$name${R}  ${GRAY}$desc${R}"
        else
          echo -e "    $box ${WHITE}$name${R}  ${GRAY}$desc${R}"
        fi
      else
        # Single select — sin checkbox, solo cursor
        if [[ $vi -eq $cursor ]]; then
          echo -e "  ${CYAN}›${R} ${WHITE}${BOLD}$name${R}  ${GRAY}$desc${R}"
        else
          echo -e "    ${WHITE}$name${R}  ${GRAY}$desc${R}"
        fi
      fi
      ((lines++))
    done

    # Footer con seleccionados (solo multi)
    if [[ "$multi" == "true" && ${#SEL_INDICES[@]} -gt 0 ]]; then
      local names=() s
      for s in "${SEL_INDICES[@]}"; do names+=("${ITEMS_NAMES[$s]}"); done
      echo ""
      echo -e "  ${GREEN}Selected:${R} $(IFS=', '; echo "${names[*]}")"
      ((lines+=2))
    fi

    menu_height=$lines
  }

  printf '\033[?25l'
  trap 'printf "\033[?25h"; echo ""; exit 130' INT TERM
  trap 'printf "\033[?25h"' EXIT

  _filter
  _render

  local key esc
  while true; do
    key=""; _key key

    # Ctrl+C o Ctrl+D — salir limpio
    if [[ "$key" == $'\x03' || "$key" == $'\x04' ]]; then
      printf '\033[?25h'
      echo ""
      exit 130
    fi

    if [[ "$key" == $'\x1b' ]]; then
      esc=""; _key esc
      if [[ "$esc" == '[' ]]; then
        _key esc
        case "$esc" in
          'A') [[ $cursor -gt 0 ]] && ((cursor--)); _render ;;
          'B') local vc=${#visible[@]}; [[ $cursor -lt $((vc-1)) ]] && ((cursor++)); _render ;;
        esac
      fi
    elif [[ "$multi" == "true" && "$key" == ' ' ]]; then
      [[ ${#visible[@]} -gt 0 ]] && _toggle "${visible[$cursor]}" && _render
    elif [[ "$multi" == "true" && ( "$key" == 'a' || "$key" == 'A' ) && -z "$search" ]]; then
      # Seleccionar todos
      SEL_INDICES=()
      local i; for i in "${!ITEMS_NAMES[@]}"; do SEL_INDICES+=("$i"); done
      _render
    elif [[ "$key" == $'\n' || "$key" == $'\r' || "$key" == '' ]]; then
      if [[ "$multi" == "true" ]]; then
        [[ ${#SEL_INDICES[@]} -eq 0 && ${#visible[@]} -gt 0 ]] && _toggle "${visible[$cursor]}"
      else
        [[ ${#visible[@]} -gt 0 ]] && SEL_INDICES=("${visible[$cursor]}")
      fi
      break
    elif [[ "$key" == $'\x7f' || "$key" == $'\x08' ]]; then
      [[ -n "$search" ]] && search="${search%?}" && cursor=0 && _render
    elif [[ -n "$key" && "$key" =~ [[:print:]] ]]; then
      search+="$key"; cursor=0; _render
    fi
  done

  printf '\033[?25h'
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

# Reiniciar terminal sin scroll — banner aparece pegado arriba
if command -v tput &>/dev/null; then
  tput reset
else
  printf '\033c'
fi

cat << "EOF"
    ____                               
   / __ \___  __  ______  ____ _       
  / / / / _ \/ / / / __ \/ __ `/       
 / /_/ /  __/ /_/ / / / / /_/ /        
/_____/\___/\__,_/_/ /_/\__,_/         
EOF
echo -e "  ${CYAN}${BOLD} @deuna/agent-skills ${R}"
echo ""

# ── Step 1: cargar registry ────────────────────────────────────────────────────
tl_pending "Loading skill registry..."
load_registry
local_total=${#REGISTRY_NAMES[@]}

if [[ $local_total -eq 0 ]]; then
  echo -e "  ✗  No skills found. Check: $RAW_BASE/registry.json"
  exit 1
fi

tl_done "Found ${CYAN}${BOLD}$local_total${R} skills"
tl_info "Source: $RAW_BASE/registry.json"
echo ""

# ── Step 2: elegir tecnología ──────────────────────────────────────────────────
tl_ask "Which technology?"
echo ""

ALL_TECHS=( $(get_unique_techs) )

ITEMS_NAMES=()
ITEMS_DESCS=()
for tech in "${ALL_TECHS[@]}"; do
  count=0
  for t in "${REGISTRY_TECHS[@]}"; do [[ "$t" == "$tech" ]] && ((count++)) || true; done
  ITEMS_NAMES+=("$tech")
  ITEMS_DESCS+=("$count skills available")
done

run_selector "false"   # single select

if [[ ${#SEL_INDICES[@]} -eq 0 ]]; then
  echo -e "  ${GRAY}Nothing selected. Exiting.${R}"; echo ""; exit 0
fi

CHOSEN_TECH="${ITEMS_NAMES[${SEL_INDICES[0]}]}"
tl_done "Technology: ${CYAN}${BOLD}$CHOSEN_TECH${R}"
echo ""

# ── Step 3: elegir skills ──────────────────────────────────────────────────────
tl_ask "Which skills? ${GRAY}(space to select, a for all)${R}"
echo ""

get_skills_for_tech "$CHOSEN_TECH"

ITEMS_NAMES=("${FILTERED_NAMES[@]}")
ITEMS_DESCS=("${FILTERED_DESCS[@]}")

run_selector "true"    # multi select

if [[ ${#SEL_INDICES[@]} -eq 0 ]]; then
  echo -e "  ${GRAY}Nothing selected. Exiting.${R}"; echo ""; exit 0
fi

# Confirmar selección
CHOSEN_SKILLS=()
for idx in "${SEL_INDICES[@]}"; do
  CHOSEN_SKILLS+=("${ITEMS_NAMES[$idx]}")
done

label=$(IFS=', '; echo "${CHOSEN_SKILLS[*]}")
tl_done "Skills: ${CYAN}$label${R}"
echo ""

# ── Step 4: directorio destino ─────────────────────────────────────────────────
DEFAULT_PROJECT="$(pwd)"
tl_ask "Install to: ${CYAN}$DEFAULT_PROJECT/.opencode/skills/${R}"
echo -ne "  ${GRAY}◇${R}  Use this path? ${GRAY}[Y/n]${R} "
_input use_default
use_default="${use_default:-Y}"

if [[ ! "$use_default" =~ ^[Yy]$ ]]; then
  echo -ne "  ${GRAY}◇${R}  Project path: "
  while true; do
    _input DEFAULT_PROJECT
    DEFAULT_PROJECT="${DEFAULT_PROJECT/#\~/$HOME}"
    [[ -d "$DEFAULT_PROJECT" ]] && break
    echo -ne "  ${YELLOW}!${R}  Not found. Try again: "
  done
fi

TARGET_DIR="$DEFAULT_PROJECT/.opencode/skills"
tl_done "Target: ${CYAN}$TARGET_DIR${R}"
echo ""

# ── Instalar ───────────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR"

for skill in "${CHOSEN_SKILLS[@]}"; do
  install_skill "$CHOSEN_TECH" "$skill" "$TARGET_DIR"
  tl_done "Installed ${CYAN}${BOLD}$skill${R}"
done

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}Done!${R}  ${#CHOSEN_SKILLS[@]} skill(s) installed."
echo ""
tl_info "Restart OpenCode to load the new skills."
echo ""
if [[ "$MODE" == "remote" ]]; then
  tl_info "To update:  curl -fsSL $RAW_BASE/setup.sh | bash"
else
  tl_info "To update:  git pull  (symlinks sync automatically)"
fi
echo ""