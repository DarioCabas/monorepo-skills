#!/usr/bin/env bash
# setup.sh — DEUNA Agent Skills installer
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/DarioCabas/monorepo-skills/main/setup.sh | bash
#   ./setup.sh   (repo clonado localmente)

# Forzar bash explícitamente — evita correr con sh/dash
if [ -z "$BASH_VERSION" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

GITHUB_ORG="DarioCabas"
GITHUB_REPO="monorepo-skills"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_BRANCH"

# ── Colors ─────────────────────────────────────────────────────────────────────
R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m'; GRAY='\033[90m'; WHITE='\033[97m'

# ── Detectar modo ──────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
[[ -d "$SKILLS_SRC" ]] && MODE="local" || MODE="remote"
[[ "$MODE" == "remote" ]] && { command -v curl &>/dev/null || { echo "curl is required"; exit 1; }; }

# ── read compatible con curl | bash ───────────────────────────────────────────
_input() {
  if [[ -t 0 ]]; then
    read -r "$1"
  elif [[ -e /dev/tty ]]; then
    read -r "$1" </dev/tty
  else
    read -r "$1"
  fi
}

_key() {
  if [[ -t 0 ]]; then
    IFS= read -r -s -n1 "$1" 2>/dev/null || true
  elif [[ -e /dev/tty ]]; then
    IFS= read -r -s -n1 "$1" </dev/tty 2>/dev/null || true
  else
    IFS= read -r -s -n1 "$1" 2>/dev/null || true
  fi
}

# ── Cargar registry ────────────────────────────────────────────────────────────
# Arrays globales — sin namerefs para compatibilidad
REGISTRY_TECHS=()
REGISTRY_NAMES=()
REGISTRY_DESCS=()

load_registry() {
  local json=""

  if [[ "$MODE" == "local" ]] && [[ -f "$REPO_DIR/registry.json" ]]; then
    json=$(cat "$REPO_DIR/registry.json")
  else
    json=$(curl -fsSL "$RAW_BASE/registry.json" 2>/dev/null) \
      || { echo -e "  ${RED}✗${R} Could not load registry"; exit 1; }
  fi

  # Parsear JSON con Python (disponible en mac/linux/WSL por defecto)
  # Fallback a sed si Python no está disponible
  if command -v python3 &>/dev/null; then
    local parsed
    parsed=$(python3 - "$json" << 'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
for s in data.get("skills", []):
    desc = s.get("description","").replace("\n"," ")[:55]
    print("{}\t{}\t{}".format(s["tech"], s["name"], desc))
PYEOF
)
    while IFS=$'\t' read -r tech name desc; do
      [[ -n "$name" ]] || continue
      REGISTRY_TECHS+=("$tech")
      REGISTRY_NAMES+=("$name")
      REGISTRY_DESCS+=("$desc")
    done <<< "$parsed"

  elif command -v python &>/dev/null; then
    local parsed
    parsed=$(python - "$json" << 'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
for s in data.get("skills", []):
    desc = s.get("description","").replace("\n"," ")[:55]
    print("{}\t{}\t{}".format(s["tech"], s["name"], desc))
PYEOF
)
    while IFS=$'\t' read -r tech name desc; do
      [[ -n "$name" ]] || continue
      REGISTRY_TECHS+=("$tech")
      REGISTRY_NAMES+=("$name")
      REGISTRY_DESCS+=("$desc")
    done <<< "$parsed"

  else
    # Fallback: sed — asume una línea por skill en el JSON
    while IFS= read -r line; do
      local tech name desc
      tech=$(echo "$line" | sed -n 's/.*"tech":"\([^"]*\)".*/\1/p')
      name=$(echo "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
      desc=$(echo "$line" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p' | cut -c1-55)
      [[ -n "$name" ]] || continue
      REGISTRY_TECHS+=("$tech")
      REGISTRY_NAMES+=("$name")
      REGISTRY_DESCS+=("$desc")
    done < <(echo "$json" | tr ',' '\n')
  fi
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
# SELECTOR INTERACTIVO — flechas + space + enter + search
# ══════════════════════════════════════════════════════════════════════════════
# Resultado en: SELECTED_INDICES=()
SELECTED_INDICES=()

interactive_select() {
  local total=${#REGISTRY_NAMES[@]}
  local cursor=0
  local search=""
  SELECTED_INDICES=()

  local -a visible=()
  local menu_height=0

  filter_visible() {
    visible=()
    local i
    for i in "${!REGISTRY_NAMES[@]}"; do
      if [[ -z "$search" ]] || \
         echo "${REGISTRY_NAMES[$i]} ${REGISTRY_DESCS[$i]}" | grep -qi "$search" 2>/dev/null; then
        visible+=("$i")
      fi
    done
  }

  is_selected() {
    local s
    for s in "${SELECTED_INDICES[@]+"${SELECTED_INDICES[@]}"}"; do
      [[ "$s" == "$1" ]] && return 0
    done
    return 1
  }

  toggle() {
    local idx="$1" found=false s
    local new=()
    for s in "${SELECTED_INDICES[@]+"${SELECTED_INDICES[@]}"}"; do
      if [[ "$s" == "$idx" ]]; then found=true; else new+=("$s"); fi
    done
    if [[ "$found" == true ]]; then
      SELECTED_INDICES=("${new[@]+"${new[@]}"}")
    else
      SELECTED_INDICES+=("$idx")
    fi
  }

  render() {
    filter_visible
    local vis_count=${#visible[@]}
    [[ $cursor -ge $vis_count && $vis_count -gt 0 ]] && cursor=$((vis_count - 1))

    # Limpiar líneas anteriores
    if [[ $menu_height -gt 0 ]]; then
      local _i
      for _i in $(seq 1 $menu_height); do printf '\033[1A\033[2K'; done
    fi

    local lines=0

    # Barra de búsqueda
    echo -e "  ${GRAY}Search:${R} ${WHITE}$search${R}${CYAN}▌${R}"
    echo -e "  ${GRAY}↑↓ move · space select · enter confirm · type to filter${R}"
    ((lines+=2))

    local prev_tech="" vi orig tech name desc box
    for vi in "${!visible[@]}"; do
      orig=${visible[$vi]}
      tech="${REGISTRY_TECHS[$orig]}"
      name="${REGISTRY_NAMES[$orig]}"
      desc="${REGISTRY_DESCS[$orig]}"

      # Header de grupo
      if [[ "$tech" != "$prev_tech" ]]; then
        echo -e "  ${GRAY}── ${BOLD}$tech${R}${GRAY} ──────────────────────────────${R}"
        ((lines++))
        prev_tech="$tech"
      fi

      # Checkbox
      if is_selected "$orig"; then box="${GREEN}◆${R}"; else box="${GRAY}◇${R}"; fi

      # Item
      if [[ $vi -eq $cursor ]]; then
        echo -e "  ${CYAN}›${R} $box ${WHITE}${BOLD}$name${R}  ${GRAY}$desc${R}"
      else
        echo -e "    $box ${WHITE}$name${R}  ${GRAY}$desc${R}"
      fi
      ((lines++))
    done

    # Footer con seleccionados
    if [[ ${#SELECTED_INDICES[@]} -gt 0 ]]; then
      local sel_names=() s
      for s in "${SELECTED_INDICES[@]}"; do sel_names+=("${REGISTRY_NAMES[$s]}"); done
      echo ""
      echo -e "  ${GREEN}Selected:${R} $(IFS=', '; echo "${sel_names[*]}")"
      ((lines+=2))
    fi

    menu_height=$lines
  }

  printf '\033[?25l'   # ocultar cursor
  trap 'printf "\033[?25h"' EXIT INT TERM

  filter_visible
  render

  local key esc
  while true; do
    key=""
    _key key

    if [[ "$key" == $'\x1b' ]]; then
      esc=""
      _key esc
      if [[ "$esc" == '[' ]]; then
        _key esc
        case "$esc" in
          'A') # Arriba
            [[ $cursor -gt 0 ]] && ((cursor--))
            render ;;
          'B') # Abajo
            local vc=${#visible[@]}
            [[ $cursor -lt $((vc - 1)) ]] && ((cursor++))
            render ;;
        esac
      fi
    elif [[ "$key" == ' ' ]]; then
      [[ ${#visible[@]} -gt 0 ]] && toggle "${visible[$cursor]}" && render
    elif [[ "$key" == $'\n' || "$key" == $'\r' || "$key" == '' ]]; then
      # Enter — si nada seleccionado, seleccionar el actual
      if [[ ${#SELECTED_INDICES[@]} -eq 0 && ${#visible[@]} -gt 0 ]]; then
        toggle "${visible[$cursor]}"
      fi
      break
    elif [[ "$key" == $'\x7f' || "$key" == $'\x08' ]]; then
      # Backspace
      [[ -n "$search" ]] && search="${search%?}" && cursor=0 && render
    elif [[ -n "$key" && "$key" =~ [[:print:]] ]]; then
      search+="$key"
      cursor=0
      render
    fi
  done

  printf '\033[?25h'  # restaurar cursor
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════
clear

# ASCII header
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
    ___  _______  __  ___  _____
   / _ \/ __/ / \/ / / _ \/ ___/
  / // / _// /\  / / // / (_ /
 /____/___/_/ /_/ /____/\___/
BANNER
echo -e "${R}"
echo -e "  ${CYAN}${BOLD} @deuna/agent-skills ${R}"
echo ""

timeline_step() { echo -e "  ${GRAY}◇${R}  $1"; }
timeline_done() { echo -e "  ${GREEN}◆${R}  $1"; }
timeline_info() { echo -e "  ${GRAY}|${R}  ${DIM}$1${R}"; }

# ── Cargar registry ────────────────────────────────────────────────────────────
timeline_step "Loading skill registry..."
load_registry
local_total=${#REGISTRY_NAMES[@]}

if [[ $local_total -eq 0 ]]; then
  echo -e "  ${RED}✗${R}  No skills found in registry."
  echo -e "  ${GRAY}|${R}  ${DIM}Check: $RAW_BASE/registry.json${R}"
  exit 1
fi

timeline_done "Found ${CYAN}${BOLD}$local_total${R} skills"
timeline_info "Source: $RAW_BASE/registry.json"
echo ""

# ── Selección interactiva ──────────────────────────────────────────────────────
echo -e "  ${YELLOW}◆${R}  ${BOLD}Which skills do you want to install?${R}"
echo ""

interactive_select

if [[ ${#SELECTED_INDICES[@]} -eq 0 ]]; then
  echo -e "  ${GRAY}Nothing selected. Exiting.${R}"
  echo ""
  exit 0
fi

for idx in "${SELECTED_INDICES[@]}"; do
  timeline_done "Selected: ${CYAN}${REGISTRY_NAMES[$idx]}${R}"
done
echo ""

# ── Directorio destino ─────────────────────────────────────────────────────────
DEFAULT_PROJECT="$(pwd)"
echo -e "  ${YELLOW}◆${R}  ${BOLD}Install to:${R} ${CYAN}$DEFAULT_PROJECT/.opencode/skills/${R}"
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
timeline_done "Target: ${CYAN}$TARGET_DIR${R}"
echo ""

# ── Instalar ───────────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR"

for idx in "${SELECTED_INDICES[@]}"; do
  local tech="${REGISTRY_TECHS[$idx]}"
  local skill="${REGISTRY_NAMES[$idx]}"
  install_skill "$tech" "$skill" "$TARGET_DIR"
  timeline_done "Installed ${CYAN}${BOLD}$skill${R}"
done

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}Done!${R}  ${#SELECTED_INDICES[@]} skill(s) installed."
echo ""
echo -e "  ${GRAY}Restart OpenCode to load the new skills.${R}"
echo ""
if [[ "$MODE" == "remote" ]]; then
  echo -e "  ${GRAY}To update:  curl -fsSL $RAW_BASE/setup.sh | bash${R}"
else
  echo -e "  ${GRAY}To update:  git pull  (symlinks sync automatically)${R}"
fi
echo ""