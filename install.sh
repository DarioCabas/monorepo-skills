#!/usr/bin/env bash

# OpenCode Skills Installer - Simple & Direct
# Usage: curl -sSL https://raw.githubusercontent.com/[user]/monorepo-skills/main/install.sh | bash -s -- [options]

set -e

REPO_URL="https://github.com/dacabasc/monorepo-skills"
REPO_RAW="https://raw.githubusercontent.com/dacabasc/monorepo-skills/main"
TARGET_DIR=".opencode/skill"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print functions
success() { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
header() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}\n"; }

# Show usage
usage() {
    cat << EOF
Usage: $0 [SKILL]

Install OpenCode skills directly to your project.

OPTIONS:
    all                         Install all skills
    react-native               Install all React Native skills
    angular                    Install all Angular skills
    nestjs                     Install all NestJS skills
    react-native/best-practices    Install specific skill

EXAMPLES:
    # Install all skills
    $0 all

    # Install all React Native skills
    $0 react-native

    # Install specific skill
    $0 react-native/best-practices

EOF
}

# Download file from GitHub
download() {
    local path="$1"
    local output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL "$REPO_RAW/$path" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$REPO_RAW/$path" -O "$output"
    else
        echo "Error: curl or wget required"
        exit 1
    fi
}

# Install a single skill
install_skill() {
    local skill_path="$1"
    local skill_name=$(basename "$skill_path")
    local target="$TARGET_DIR/$skill_name"
    
    info "Instalando $skill_path..."
    
    mkdir -p "$target"
    
    # Download SKILL.md
    if download "skills/$skill_path/SKILL.md" "$target/SKILL.md" 2>/dev/null; then
        success "$skill_name instalado"
    else
        echo "Error: No se pudo descargar $skill_path"
        rm -rf "$target"
        return 1
    fi
}

# Install all skills from a technology
install_tech() {
    local tech="$1"
    
    header "Instalando skills de $tech"
    
    case "$tech" in
        react-native)
            install_skill "react-native/best-practices"
            install_skill "react-native/upgrade-workflow"
            install_skill "react-native/component-patterns"
            ;;
        angular)
            install_skill "angular/best-practices"
            install_skill "angular/performance"
            ;;
        nestjs)
            install_skill "nestjs/best-practices"
            install_skill "nestjs/api-design"
            ;;
        *)
            echo "Tecnología no reconocida: $tech"
            echo "Disponibles: react-native, angular, nestjs"
            exit 1
            ;;
    esac
}

# Install all skills
install_all() {
    header "Instalando todas las skills"
    
    install_tech "react-native"
    install_tech "angular"
    install_tech "nestjs"
    
    echo ""
    success "Todas las skills instaladas!"
}

# List installed skills
list_installed() {
    if [ ! -d "$TARGET_DIR" ]; then
        info "No hay skills instaladas"
        return
    fi
    
    header "Skills instaladas"
    
    for skill in "$TARGET_DIR"/*; do
        if [ -d "$skill" ] && [ -f "$skill/SKILL.md" ]; then
            name=$(grep "^name:" "$skill/SKILL.md" | sed 's/name: //' | head -1)
            echo -e "${GREEN}✓${NC} $name"
        fi
    done
}

# Main
main() {
    # Create target directory
    mkdir -p "$TARGET_DIR"
    
    # Parse argument
    case "${1:-}" in
        all)
            install_all
            ;;
        react-native|angular|nestjs)
            install_tech "$1"
            ;;
        */*)
            install_skill "$1"
            ;;
        ""|--help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Opción no reconocida: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
    
    echo ""
    list_installed
    echo ""
    info "Skills instaladas en: $TARGET_DIR"
    info "OpenCode las usará automáticamente"
}

main "$@"
