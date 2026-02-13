#!/usr/bin/env bash
#
# Skills Setup Script for Multiple AI Coding Assistants
# Based on agentskills.io standard
#
# Usage:
#   ./skills/setup.sh [target_directory]
#   
# If no directory is provided, assumes current working directory
#

set -e

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  AI Skills Setup - Multi-Agent Installer${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✔${NC} $1"
}

print_error() {
    echo -e "${RED}✖${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Detect which AI coding assistants are configured
detect_agents() {
    local agents=()
    
    if [ -d "$TARGET_DIR/.claude" ]; then
        agents+=("Claude Code")
    fi
    
    if [ -d "$TARGET_DIR/.opencode" ]; then
        agents+=("OpenCode")
    fi
    
    if [ -d "$TARGET_DIR/.cursor" ]; then
        agents+=("Cursor")
    fi
    
    if [ -d "$TARGET_DIR/.github" ]; then
        agents+=("GitHub Copilot")
    fi
    
    if [ -d "$TARGET_DIR/.gemini" ]; then
        agents+=("Gemini CLI")
    fi
    
    if [ -d "$TARGET_DIR/.codex" ]; then
        agents+=("Codex")
    fi
    
    echo "${agents[@]}"
}

# Install skills for Claude Code (symlink)
install_claude() {
    local target="$TARGET_DIR/.claude/skills"
    mkdir -p "$(dirname "$target")"
    
    if [ -L "$target" ]; then
        rm "$target"
    fi
    
    ln -sf "$SKILLS_DIR" "$target"
    print_success "Claude Code: Skills linked to .claude/skills/"
}

# Install skills for OpenCode (copy with technology structure)
install_opencode() {
    local target="$TARGET_DIR/.opencode/skill"
    mkdir -p "$target"
    
    # Copy technology directories (react-native, angular, nestjs)
    for tech_path in "$SKILLS_DIR"/*; do
        if [ -d "$tech_path" ]; then
            tech_name=$(basename "$tech_path")
            # Skip hidden files
            if [[ ! "$tech_name" =~ ^\. ]]; then
                cp -r "$tech_path" "$target/" 2>/dev/null || true
            fi
        fi
    done
    
    print_success "OpenCode: Skills copied to .opencode/skill/"
}

# Install skills for Cursor (symlink to .cursor/rules)
install_cursor() {
    local target="$TARGET_DIR/.cursor/rules"
    mkdir -p "$(dirname "$target")"
    
    if [ -L "$target" ]; then
        rm "$target"
    fi
    
    ln -sf "$SKILLS_DIR" "$target"
    print_success "Cursor: Skills linked to .cursor/rules/"
}

# Install skills for GitHub Copilot (symlink)
install_copilot() {
    local target="$TARGET_DIR/.github/skills"
    mkdir -p "$(dirname "$target")"
    
    if [ -L "$target" ]; then
        rm "$target"
    fi
    
    ln -sf "$SKILLS_DIR" "$target"
    print_success "GitHub Copilot: Skills linked to .github/skills/"
}

# Install skills for Gemini CLI (symlink)
install_gemini() {
    local target="$TARGET_DIR/.gemini/skills"
    mkdir -p "$(dirname "$target")"
    
    if [ -L "$target" ]; then
        rm "$target"
    fi
    
    ln -sf "$SKILLS_DIR" "$target"
    print_success "Gemini CLI: Skills linked to .gemini/skills/"
}

# Install skills for Codex (symlink)
install_codex() {
    local target="$TARGET_DIR/.codex/skills"
    mkdir -p "$(dirname "$target")"
    
    if [ -L "$target" ]; then
        rm "$target"
    fi
    
    ln -sf "$SKILLS_DIR" "$target"
    print_success "Codex: Skills linked to .codex/skills/"
}

# Main installation logic
main() {
    print_header
    
    cd "$TARGET_DIR"
    
    print_info "Skills directory: $SKILLS_DIR"
    print_info "Target directory: $TARGET_DIR"
    echo ""
    
    local agents
    agents=($(detect_agents))
    
    if [ ${#agents[@]} -eq 0 ]; then
        print_warning "No AI coding assistants detected in $TARGET_DIR"
        print_info "Creating directories for common assistants..."
        echo ""
        
        # Create common directories
        mkdir -p .claude .opencode .cursor .github
        
        install_claude
        install_opencode
        install_cursor
        install_copilot
    else
        print_info "Detected AI agents:"
        for agent in "${agents[@]}"; do
            echo "  - $agent"
        done
        echo ""
        
        # Install for each detected agent
        for agent in "${agents[@]}"; do
            case "$agent" in
                "Claude Code")
                    install_claude
                    ;;
                "OpenCode")
                    install_opencode
                    ;;
                "Cursor")
                    install_cursor
                    ;;
                "GitHub Copilot")
                    install_copilot
                    ;;
                "Gemini CLI")
                    install_gemini
                    ;;
                "Codex")
                    install_codex
                    ;;
            esac
        done
    fi
    
    echo ""
    print_success "Skills setup complete!"
    echo ""
    print_warning "Remember to restart your AI coding assistant to load the skills"
    
    # Count total skills
    local skill_count
    skill_count=$(find "$SKILLS_DIR" -name "SKILL.md" | wc -l | tr -d ' ')
    print_info "Total skills available: $skill_count"
}

main "$@"
