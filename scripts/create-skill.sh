#!/usr/bin/env bash
# create-skill.sh — Crea un nuevo skill con TUI interactiva
#
# Uso:
#   bash scripts/create-skill.sh
#   bash scripts/create-skill.sh react-native rn-animations
#
# Lo que hace:
#   1. Pide tecnología (existente o nueva)
#   2. Pide nombre del skill
#   3. Pide descripción corta
#   4. Pide trigger clause
#   5. Genera skills/<tech>/<name>/SKILL.md desde el template
#   6. Regenera registry.json
#   7. Abre el editor

if [ -z "$BASH_VERSION" ]; then exec bash "$0" "$@"; fi
set -euo pipefail

# ── Colores ────────────────────────────────────────────────────────────────────
R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'
GRAY='\033[90m'; WHITE='\033[97m'; RED='\033[31m'

# ── Paths ──────────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
TEMPLATE="$REPO_DIR/skills/generic/skill-creator/assets/SKILL-TEMPLATE.md"
REGISTRY_SCRIPT="$REPO_DIR/scripts/build-registry.sh"

# ── Timeline helpers ───────────────────────────────────────────────────────────
tl_done() { echo -e "  ${GREEN}◆${R}  $1"; }
tl_ask()  { echo -e "  ${YELLOW}◆${R}  ${BOLD}$1${R}"; }
tl_info() { echo -e "  ${GRAY}|  ${DIM}$1${R}"; }
tl_err()  { echo -e "  ${RED}✗${R}  $1"; }

ask_input() {
  # $1 = label, $2 = variable name, $3 = default (opcional)
  local label="$1" varname="$2" default="${3:-}"
  if [[ -n "$default" ]]; then
    echo -ne "  ${GRAY}◇${R}  $label ${GRAY}[$default]${R}: "
  else
    echo -ne "  ${GRAY}◇${R}  $label: "
  fi
  read -r "$varname"
  # Si vacío y hay default, usar default
  local val="${!varname}"
  if [[ -z "$val" && -n "$default" ]]; then
    printf -v "$varname" '%s' "$default"
  fi
}

# ── Banner ─────────────────────────────────────────────────────────────────────
printf '\033c'
cat << "EOF"
    ____                               
   / __ \___  __  ______  ____ _       
  / / / / _ \/ / / / __ \/ __ `/       
 / /_/ /  __/ /_/ / / / / /_/ /        
/_____/\___/\__,_/_/ /_/\__,_/         
EOF
echo -e "  ${CYAN}${BOLD} @deuna/agent-skills ${R}  ${GRAY}new skill${R}"
echo ""

# ── Args opcionales ────────────────────────────────────────────────────────────
ARG_TECH="${1:-}"
ARG_NAME="${2:-}"

# ── Step 1: Tecnología ─────────────────────────────────────────────────────────
tl_ask "Technology"
echo ""

# Listar tecnologías existentes
EXISTING_TECHS=()
if [[ -d "$SKILLS_DIR" ]]; then
  while IFS= read -r d; do
    EXISTING_TECHS+=("$(basename "$d")")
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [[ ${#EXISTING_TECHS[@]} -gt 0 ]]; then
  echo -e "  ${GRAY}Existing technologies:${R}"
  i=1
  for t in "${EXISTING_TECHS[@]}"; do
    count=$(find "$SKILLS_DIR/$t" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GRAY}$i)${R}  ${WHITE}$t${R}  ${GRAY}($count skills)${R}"
    ((i++))
  done
  echo -e "  ${GRAY}n)${R}  New technology"
  echo ""
fi

TECH=""
if [[ -n "$ARG_TECH" ]]; then
  TECH="$ARG_TECH"
  tl_done "Technology: ${CYAN}${BOLD}$TECH${R}"
else
  while [[ -z "$TECH" ]]; do
    if [[ ${#EXISTING_TECHS[@]} -gt 0 ]]; then
      echo -ne "  ${GRAY}◇${R}  Choose [1-$((i-1)) or n]: "
      read -r choice
      if [[ "$choice" == "n" || "$choice" == "N" ]]; then
        echo -ne "  ${GRAY}◇${R}  Technology name: "
        read -r TECH
      elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
        TECH="${EXISTING_TECHS[$((choice-1))]}"
      else
        echo -e "  ${YELLOW}!${R}  Invalid option"
        continue
      fi
    else
      echo -ne "  ${GRAY}◇${R}  Technology name: "
      read -r TECH
    fi

    # Validar formato: solo lowercase, números y guiones
    if [[ ! "$TECH" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      echo -e "  ${YELLOW}!${R}  Use lowercase and hyphens only (e.g. react-native)"
      TECH=""
    fi
  done
  tl_done "Technology: ${CYAN}${BOLD}$TECH${R}"
fi

echo ""

# ── Step 2: Nombre del skill ───────────────────────────────────────────────────
tl_ask "Skill name"
tl_info "Use lowercase + hyphens  e.g. rn-animations, ng-forms, vue-composables"
echo ""

NAME=""
if [[ -n "$ARG_NAME" ]]; then
  NAME="$ARG_NAME"
else
  while [[ -z "$NAME" ]]; do
    echo -ne "  ${GRAY}◇${R}  Name: "
    read -r NAME

    if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      echo -e "  ${YELLOW}!${R}  Use lowercase and hyphens only"
      NAME=""; continue
    fi

    if [[ -d "$SKILLS_DIR/$TECH/$NAME" ]]; then
      echo -e "  ${YELLOW}!${R}  '$TECH/$NAME' already exists. Choose a different name."
      NAME=""; continue
    fi
  done
fi

tl_done "Name: ${CYAN}${BOLD}$NAME${R}"
echo ""

# ── Step 3: Descripción ────────────────────────────────────────────────────────
tl_ask "Description"
tl_info "One line, shown in the installer. What does this skill detect or enforce?"
echo ""

DESCRIPTION=""
while [[ -z "$DESCRIPTION" ]]; do
  echo -ne "  ${GRAY}◇${R}  Description: "
  read -r DESCRIPTION
  if [[ -z "$DESCRIPTION" ]]; then
    echo -e "  ${YELLOW}!${R}  Description is required"
  fi
done

tl_done "Description: ${GRAY}$DESCRIPTION${R}"
echo ""

# ── Step 4: Trigger — sugerido desde la description ───────────────────────────
# Inferir trigger: extraer verbos/contexto clave de la description
# Patrones: "Detects X" → "user reports X", "Applies X to Y" → "user asks to refactor Y", etc.
SUGGESTED_TRIGGER=""

desc_lower=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')

if echo "$desc_lower" | grep -qE "detect|eliminat|find|identify|prevent"; then
  # "Detects unnecessary re-renders" → "user reports performance issues or re-renders"
  subject=$(echo "$DESCRIPTION" | sed 's/[Dd]etects //;s/[Ee]liminates //;s/[Ff]inds //;s/[Ii]dentifies //' | cut -c1-50)
  SUGGESTED_TRIGGER="user reports $subject"
elif echo "$desc_lower" | grep -qE "appl|enforc|ensur|implement"; then
  # "Applies SOLID to Angular" → "user asks to refactor or review Angular code"
  SUGGESTED_TRIGGER="user asks to refactor, review, or write $TECH code"
elif echo "$desc_lower" | grep -qE "creat|generat|scaffold|build"; then
  subject=$(echo "$DESCRIPTION" | sed 's/[Cc]reates\? //;s/[Gg]enerates\? //;s/[Ss]caffolds\? //' | cut -c1-40)
  SUGGESTED_TRIGGER="user wants to create $subject"
elif echo "$desc_lower" | grep -qE "migrat|upgrad|convert"; then
  SUGGESTED_TRIGGER="user needs to migrate or upgrade existing $TECH code"
elif echo "$desc_lower" | grep -qE "optim|improv|speed|performance|fast"; then
  SUGGESTED_TRIGGER="user reports performance issues or wants to optimize $TECH code"
fi

tl_ask "Trigger"
if [[ -n "$SUGGESTED_TRIGGER" ]]; then
  tl_info "Suggested based on your description — press Enter to accept or type a new one"
  echo ""
  echo -ne "  ${GRAY}◇${R}  Trigger: When ${CYAN}$SUGGESTED_TRIGGER${R} "
  echo -ne "${GRAY}[Enter to accept]${R} "
  read -r TRIGGER_INPUT
  TRIGGER="${TRIGGER_INPUT:-$SUGGESTED_TRIGGER}"
else
  tl_info "Complete: 'Trigger: When ...'"
  echo ""
  echo -ne "  ${GRAY}◇${R}  Trigger: When "
  read -r TRIGGER
  while [[ -z "$TRIGGER" ]]; do
    echo -e "  ${YELLOW}!${R}  Trigger is required"
    echo -ne "  ${GRAY}◇${R}  Trigger: When "
    read -r TRIGGER
  done
fi

tl_done "Trigger: ${GRAY}When $TRIGGER${R}"
echo ""

# ── Generar SKILL.md desde el template oficial ────────────────────────────────
DEST="$SKILLS_DIR/$TECH/$NAME"
TEMPLATE="$REPO_DIR/skills/generic/skill-creator/assets/SKILL-TEMPLATE.md"

if [[ ! -f "$TEMPLATE" ]]; then
  echo -e "  ${RED}✗${R}  Template not found: $TEMPLATE"
  exit 1
fi

mkdir -p "$DEST"

DATE=$(date +%Y-%m-%d)

# Copiar template y reemplazar placeholders
sed \
  -e "s|^name: skill-name$|name: $NAME|" \
  -e "s|^description:.*|description: $DESCRIPTION Trigger: When $TRIGGER|" \
  -e "s|scope: react-native|scope: $TECH|" \
  -e "s|  author: deuna|  author: deuna\n  version: 1.0.0\n  created: $DATE|" \
  "$TEMPLATE" > "$DEST/SKILL.md"

tl_done "Created ${CYAN}$DEST/SKILL.md${R}"

# ── Validar el skill recién creado ─────────────────────────────────────────────
VALIDATE_SCRIPT="$REPO_DIR/scripts/validate-skills.sh"
if [[ -f "$VALIDATE_SCRIPT" ]]; then
  echo ""
  validation_output=$(bash "$VALIDATE_SCRIPT" "$DEST/SKILL.md" 2>&1)
  if echo "$validation_output" | grep -q "error"; then
    echo "$validation_output"
    echo ""
    echo -e "  ${YELLOW}⚠${R}  Skill created with validation issues — fill them in before committing"
  else
    tl_done "Validation passed"
  fi
fi

# ── Regenerar registry ─────────────────────────────────────────────────────────
if [[ -f "$REGISTRY_SCRIPT" ]]; then
  bash "$REGISTRY_SCRIPT" &>/dev/null
  tl_done "Registry updated"
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}Done!${R}  Fill in the TODOs and commit."
echo ""
tl_info "Path:  $DEST/SKILL.md"
tl_info "Next:  git add skills/$TECH/$NAME && git commit -m \"feat($TECH): add $NAME\""
echo ""

