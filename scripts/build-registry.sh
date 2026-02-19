#!/usr/bin/env bash
# build-registry.sh — Auto-genera registry.json desde la estructura de carpetas
# Correr antes de cada commit cuando se agrega un skill nuevo
# O en CI automáticamente

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
OUTPUT="$REPO_DIR/registry.json"

echo "Building registry from $SKILLS_DIR..."

# Construir JSON
json='{"skills":['
first=true

for tech_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$tech_dir" ]] || continue
  tech=$(basename "$tech_dir")

  for skill_dir in "$tech_dir"*/; do
    [[ -d "$skill_dir" ]] || continue
    skill=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue

    # Extraer description del frontmatter
    desc=$(awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
      sub(/^description: */,""); gsub(/"/,"\\\""); print; exit
    }' "$skill_file")

    [[ "$first" == true ]] && first=false || json+=','
    json+="{\"tech\":\"$tech\",\"name\":\"$skill\",\"description\":\"$desc\"}"
  done
done

json+=']}'

echo "$json" > "$OUTPUT"

# Pretty print si jq está disponible
if command -v jq &>/dev/null; then
  echo "$json" | jq . > "$OUTPUT"
fi

count=$(echo "$json" | grep -o '"name"' | wc -l | tr -d ' ')
echo "✓ registry.json updated — $count skills"