# monorepo-skills

> A monorepo of Agent Skills for AI coding assistants (Claude Code, OpenCode, Codex).  
> Organized by technology, following the [agentskills.io](https://agentskills.io) standard.

---

## 📦 Available Skills

| Technology   | Skill                                                                 | Description                                                                                                      |
| ------------ | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| React Native | [`rn-no-rerenders`](skills/react-native/rn-no-rerenders/SKILL.md)     | Detect and eliminate unnecessary re-renders: inline refs, broken memo, FlatList churn, context over-broadcasting |
| React Native | [`rn-solid-dry-kiss`](skills/react-native/rn-solid-dry-kiss/SKILL.md) | Apply SOLID, DRY, KISS to React Native: SRP components, DRY hooks, KISS over clever abstractions                 |
| Angular      | [`ng-no-rerenders`](skills/angular/ng-no-rerenders/SKILL.md)          | Eliminate Angular CD cycles: OnPush, signals, trackBy, zone.js, and template expression cost                     |
| Angular      | [`ng-solid-dry-kiss`](skills/angular/ng-solid-dry-kiss/SKILL.md)      | Apply SOLID, DRY, KISS to Angular: layered services, interceptors, pipes, functional guards                      |
| Generic      | [`skill-creator`](skills/generic/skill-creator/SKILL.md)              | Create or improve skills in this monorepo following the canonical template and standards                         |

---

## 🚀 Installation

### Option 1 — `npx skills add` (Vercel/OpenCode style)

```bash
npx skills add rn-component-generator --from https://github.com/YOUR_ORG/monorepo-skills
```

This copies the skill into `.opencode/skills/rn-component-generator/` in your current project.

### Option 2 — CLI propio (`skills-install`)

If Option 1 fails or no tienes npx disponible:

```bash
npx monorepo-skills install
```

Launches an interactive step-by-step installer that:

1. Shows available skills by technology
2. Lets you select one or more
3. Copies them into `.opencode/skills/` (per-project) or `~/.claude/skills/` (global)

### Option 3 — Manual (fallback definitivo)

```bash
# Clone or download the skill folder directly
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/monorepo-skills/main/scripts/install.sh | bash
```

The install script auto-detects which method works and falls back gracefully.

---

## 🗂 Repository Structure

```
monorepo-skills/
├── skills/
│   ├── react-native/
│   │   ├── rn-component-generator/   ← Skill folder
│   │   │   ├── SKILL.md              ← Required (YAML frontmatter + instructions)
│   │   │   ├── templates/            ← Component templates
│   │   │   └── examples.md           ← Usage examples
│   │   └── rn-design-system/
│   │       ├── SKILL.md
│   │       └── reference.md
│   └── angular/
│       ├── ng-component-generator/
│       │   ├── SKILL.md
│       │   └── templates/
│       └── ng-service-pattern/
│           ├── SKILL.md
│           └── examples.md
├── templates/
│   └── _skill-template/              ← Template base para nuevos skills
│       ├── SKILL.md
│       └── examples.md
├── scripts/
│   ├── install.sh                    ← Bash installer (fallback)
│   ├── create-skill.sh               ← Genera nuevo skill desde template
│   └── sync.sh                       ← Sincroniza skills a .opencode/skills/
├── .github/
│   └── workflows/
│       └── validate-skills.yml       ← CI: valida YAML frontmatter de todos los skills
└── README.md
```

---

## 🛠 Create a New Skill

```bash
# Desde la raíz del monorepo:
./scripts/create-skill.sh react-native my-new-skill
```

This copies `templates/_skill-template/` into `skills/react-native/my-new-skill/` and opens the SKILL.md for editing.

---

## 📐 Skill Format (agentskills.io standard)

Every skill must have a `SKILL.md` with YAML frontmatter:

```markdown
---
name: skill-name # lowercase, hyphens, max 64 chars
description: > # What it does + when to use it (max 1024 chars)
  Brief description of the skill and trigger conditions.
version: 1.0.0
technology: react-native # angular | react-native | generic | ...
allowed-tools: Read, Write, Bash # optional — restricts tool access
---

# Skill Name

...content...
```

---

## 🔄 Sync Skills to a Project

```bash
# Sync a specific skill
./scripts/sync.sh rn-component-generator /path/to/your/project

# Sync all React Native skills
./scripts/sync.sh --tech react-native /path/to/your/project

# Interactive mode
./scripts/sync.sh
```

---

## 📋 Best Practices

- **One skill, one capability** — no mega-skills
- **Description is key** — AI discovers skills from it; include trigger words
- **Template first** — always start from `templates/_skill-template/`
- **Version your skills** — document breaking changes in SKILL.md
- **Test before committing** — run `./scripts/validate-skills.sh` locally

---

## 🤝 Contributing

1. Use `./scripts/create-skill.sh [tech] [name]`
2. Fill in `SKILL.md` following the template
3. Add examples in `examples.md`
4. Run `./scripts/validate-skills.sh`
5. Open a PR
