#!/usr/bin/env bash
# build-registry.sh — Genera registry.json desde la estructura de skills/
#
# Uso:
#   bash scripts/build-registry.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
OUTPUT="$REPO_DIR/registry.json"

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

    desc=$(awk '/^---$/{if(NR==1){in_fm=1;next} else {exit}} in_fm && /^description:/{
      sub(/^description: */,""); gsub(/"/,"\\\""); print; exit
    }' "$skill_file")

    [[ "$first" == true ]] && first=false || json+=','
    json+="{\"tech\":\"$tech\",\"name\":\"$skill\",\"description\":\"$desc\"}"
  done
done

json+=']}'

# Pretty print con python3, fallback a raw json
if command -v python3 &>/dev/null; then
  echo "$json" | python3 -m json.tool > "$OUTPUT"
else
  echo "$json" > "$OUTPUT"
fi

count=$(grep -o '"name"' "$OUTPUT" | wc -l | tr -d ' ')
echo "registry.json  $count skills"