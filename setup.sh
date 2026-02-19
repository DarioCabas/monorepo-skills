#!/usr/bin/env bash
# setup.sh — DEUNA Agent Skills installer
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/DarioCabas/monorepo-skills/main/setup.sh | bash
#   ./setup.sh   (repo clonado localmente)

set -euo pipefail

GITHUB_ORG="DarioCabas"
GITHUB_REPO="monorepo-skills"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_ORG/$GITHUB_REPO/$GITHUB_BRANCH"

# ── Colors ─────────────────────────────────────────────────────────────────────
R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
RED='\033[31m'; GRAY='\033[90m'; WHITE='\033[97m'; BLUE='\033[34m'

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
# read sin echo (para capturar teclas especiales)
_key() {
  if [[ -t 0 ]]; then IFS= read -r -s -n1 "$1" 2>/dev/null || true
  elif [[ -e /dev/tty ]]; then IFS= read -r -s -n1 "$1" </dev/tty 2>/dev/null || true
  else IFS= read -r -s -n1 "$1" 2>/dev/null || true; fi
}

# ── Cargar registry ────────────────────────────────────────────────────────────
load_registry() {
  local json
  if [[ "$MODE" == "local" ]] && [[ -f "$REPO_DIR/registry.json" ]]; then
    json=$(cat "$REPO_DIR/registry.json")
  else
    json=$(curl -fsSL "$RAW_BASE/registry.json" 2>/dev/null) \
      || { echo -e "${RED}✗${R} Could not load registry from GitHub"; exit 1; }
  fi

  # Parsear JSON sin jq — extraer tech y name
  REGISTRY_TECHS=()
  REGISTRY_NAMES=()
  REGISTRY_DESCS=()

  while IFS= read -r line; do
    tech=$(echo "$line" | sed 's/.*"tech":"\([^"]*\)".*/\1/')
    name=$(echo "$line" | sed 's/.*"name":"\([^"]*\)".*/\1/')
    desc=$(echo "$line" | sed 's/.*"description":"\([^"]*\)".*/\1/' | cut -c1-55)
    REGISTRY_TECHS+=("$tech")
    REGISTRY_NAMES+=("$name")
    REGISTRY_DESCS+=("$desc")
  done < <(echo "$json" | grep -o '"tech":"[^"]*","name":"[^"]*","description":"[^"]*"')
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
# SELECTOR INTERACTIVO — flechas + space + enter
# Uso: interactive_select "Título" idx_array name_array desc_array
# Devuelve SELECTED_INDICES=()
# ══════════════════════════════════════════════════════════════════════════════
interactive_select() {
  local title="$1"
  local -n _techs=$2   # array de techs por item
  local -n _names=$3   # array de nombres
  local -n _descs=$4   # array de descripciones

  local total=${#_names[@]}
  local cursor=0
  local search=""
  SELECTED_INDICES=()

  # Indices visibles según search
  local -a visible=()
  filter_visible() {
    visible=()
    for i in "${!_names[@]}"; do
      if [[ -z "$search" ]] || echo "${_names[$i]} ${_descs[$i]}" | grep -qi "$search"; then
        visible+=("$i")
      fi
    done
  }

  is_selected() {
    for s in "${SELECTED_INDICES[@]+"${SELECTED_INDICES[@]}"}"; do
      [[ "$s" == "$1" ]] && return 0
    done
    return 1
  }

  toggle() {
    local idx="$1"
    local new=()
    local found=false
    for s in "${SELECTED_INDICES[@]+"${SELECTED_INDICES[@]}"}"; do
      if [[ "$s" == "$idx" ]]; then found=true; else new+=("$s"); fi
    done
    [[ "$found" == true ]] && SELECTED_INDICES=("${new[@]+"${new[@]}"}") || SELECTED_INDICES+=("$idx")
  }

  # Número de líneas que ocupa el menú en pantalla
  local menu_height=0
  render() {
    filter_visible
    local vis_count=${#visible[@]}
    [[ $cursor -ge $vis_count && $vis_count -gt 0 ]] && cursor=$((vis_count - 1))

    # Limpiar líneas anteriores
    if [[ $menu_height -gt 0 ]]; then
      for _ in $(seq 1 $menu_height); do echo -ne "\033[1A\033[2K"; done
    fi

    local lines=0

    # Search
    echo -e "  ${GRAY}Search:${R} ${WHITE}$search${R}${CYAN}▌${R}"
    echo -e "  ${GRAY}↑↓ move · space select · enter confirm · type to filter${R}"
    ((lines+=2))

    # Agrupar por tech
    local prev_tech=""
    for vi in "${!visible[@]}"; do
      local orig=${visible[$vi]}
      local tech="${_techs[$orig]}"
      local name="${_names[$orig]}"
      local desc="${_descs[$orig]}"

      # Header de grupo
      if [[ "$tech" != "$prev_tech" ]]; then
        local line="── ${BOLD}$tech${R} "
        local pad=$(printf '%.0s─' {1..30})
        echo -e "  $line${GRAY}$pad${R}"
        ((lines++))
        prev_tech="$tech"
      fi

      # Checkbox
      local box
      if is_selected "$orig"; then box="${GREEN}◆${R}"; else box="${GRAY}◇${R}"; fi

      # Cursor
      if [[ $vi -eq $cursor ]]; then
        echo -e "  ${CYAN}›${R} $box ${WHITE}${BOLD}$name${R}  ${GRAY}$desc${R}"
      else
        echo -e "    $box ${WHITE}$name${R}  ${GRAY}$desc${R}"
      fi
      ((lines++))
    done

    # Footer
    if [[ ${#SELECTED_INDICES[@]} -gt 0 ]]; then
      local sel_names=()
      for s in "${SELECTED_INDICES[@]}"; do sel_names+=("${_names[$s]}"); done
      local sel_str=$(IFS=', '; echo "${sel_names[*]}")
      echo ""
      echo -e "  ${GREEN}Selected:${R} $sel_str"
      ((lines+=2))
    fi

    menu_height=$lines
  }

  # Ocultar cursor
  echo -ne "\033[?25l"
  trap 'echo -ne "\033[?25h"' EXIT

  filter_visible
  render

  while true; do
    local key esc
    _key key

    if [[ "$key" == $'\x1b' ]]; then
      # Secuencia de escape (flechas)
      _key esc
      if [[ "$esc" == '[' ]]; then
        _key esc
        case "$esc" in
          'A') # Up
            [[ $cursor -gt 0 ]] && ((cursor--))
            render ;;
          'B') # Down
            local vis_count=${#visible[@]}
            [[ $cursor -lt $((vis_count - 1)) ]] && ((cursor++))
            render ;;
        esac
      fi
    elif [[ "$key" == ' ' ]]; then
      # Space — toggle
      if [[ ${#visible[@]} -gt 0 ]]; then
        toggle "${visible[$cursor]}"
        render
      fi
    elif [[ "$key" == $'\n' || "$key" == $'\r' || "$key" == '' ]]; then
      # Enter — confirmar
      # Si no hay nada seleccionado y hay un item bajo el cursor, seleccionarlo
      if [[ ${#SELECTED_INDICES[@]} -eq 0 && ${#visible[@]} -gt 0 ]]; then
        toggle "${visible[$cursor]}"
      fi
      break
    elif [[ "$key" == $'\x7f' || "$key" == $'\x08' ]]; then
      # Backspace
      [[ -n "$search" ]] && search="${search%?}" && cursor=0
      render
    elif [[ "$key" =~ [[:print:]] ]]; then
      # Typing — filtrar
      search+="$key"
      cursor=0
      render
    fi
  done

  # Restaurar cursor
  echo -ne "\033[?25h"
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TUI
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

# Badge
echo -e "  ${CYAN}${BOLD} @deuna/agent-skills ${R}"
echo ""

# Timeline — log de acciones
timeline_step() { echo -e "  ${GRAY}◇${R}  $1"; }
timeline_done() { echo -e "  ${GREEN}◆${R}  $1"; }
timeline_info() { echo -e "  ${GRAY}|${R}  ${DIM}$1${R}"; }

timeline_step "Loading skill registry..."
load_registry
total=${#REGISTRY_NAMES[@]}
timeline_done "Found ${CYAN}${BOLD}$total${R} skills"
timeline_info "Source: $RAW_BASE/registry.json"
echo ""

# ── Selección de skills ────────────────────────────────────────────────────────
echo -e "  ${YELLOW}◆${R}  ${BOLD}Which skills do you want to install?${R}"
echo ""

SELECTED_INDICES=()
interactive_select "Skills" REGISTRY_TECHS REGISTRY_NAMES REGISTRY_DESCS

if [[ ${#SELECTED_INDICES[@]} -eq 0 ]]; then
  echo -e "\n  ${GRAY}Nothing selected. Exiting.${R}\n"
  exit 0
fi

# Mostrar selección en timeline
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
  tech="${REGISTRY_TECHS[$idx]}"
  skill="${REGISTRY_NAMES[$idx]}"
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