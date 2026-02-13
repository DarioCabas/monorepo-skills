#!/usr/bin/env bash
#
# Skills Validator
# Validates that all SKILL.md files follow the correct format
#
# Usage:
#   ./scripts/validate-skills.sh
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

print_success() {
    echo -e "${GREEN}✔${NC} $1"
}

print_error() {
    echo -e "${RED}✖${NC} $1"
    ERRORS=$((ERRORS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Validate a single SKILL.md file
validate_skill() {
    local file="$1"
    local basename=$(basename "$file")
    
    # Check if file has YAML frontmatter
    if ! grep -q "^---" "$file"; then
        print_error "$file: Missing YAML frontmatter (should start with ---)"
        return 1
    fi
    
    # Check if file has required fields
    local has_name=$(grep -c "^name:" "$file" || true)
    local has_description=$(grep -c "^description:" "$file" || true)
    
    if [ "$has_name" -eq 0 ]; then
        print_error "$file: Missing 'name:' field in frontmatter"
    fi
    
    if [ "$has_description" -eq 0 ]; then
        print_error "$file: Missing 'description:' field in frontmatter"
    fi
    
    # Check if file is not empty (more than just frontmatter)
    local line_count=$(wc -l < "$file" | tr -d ' ')
    if [ "$line_count" -lt 10 ]; then
        print_warning "$file: File seems too short (only $line_count lines)"
    fi
    
    # If no errors for this file
    if [ "$has_name" -gt 0 ] && [ "$has_description" -gt 0 ]; then
        print_success "$file"
    fi
}

main() {
    echo "Validating SKILL.md files..."
    echo ""
    
    # Find all SKILL.md files
    local skill_files
    skill_files=$(find skills -name "SKILL.md" 2>/dev/null || true)
    
    if [ -z "$skill_files" ]; then
        print_error "No SKILL.md files found in skills/ directory"
        exit 1
    fi
    
    # Validate each file
    while IFS= read -r file; do
        validate_skill "$file"
    done <<< "$skill_files"
    
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        print_success "All skills are valid!"
        exit 0
    else
        print_error "Found $ERRORS validation error(s)"
        exit 1
    fi
}

main "$@"
