# @deuna/agent-skills

Agent Skills para React Native y Angular en DEUNA.
Siguiendo el estándar [agentskills.io](https://agentskills.io) — compatible con OpenCode, Claude Code, y Cursor.

---

## Skills disponibles

| Skill               | Tecnología   | Qué hace                                        |
| ------------------- | ------------ | ----------------------------------------------- |
| `rn-no-rerenders`   | React Native | Detecta y elimina re-renders innecesarios       |
| `rn-solid-dry-kiss` | React Native | Aplica SOLID, DRY y KISS al código RN           |
| `ng-no-rerenders`   | Angular      | Elimina ciclos de Change Detection innecesarios |
| `ng-solid-dry-kiss` | Angular      | Aplica SOLID, DRY y KISS al código Angular      |
| `skill-creator`     | Generic      | Crea o mejora skills en este monorepo           |

---

## Instalar en tu proyecto

Ve a la carpeta de tu proyecto y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/DarioCabas/monorepo-skills/main/setup.sh  -o /tmp/deuna-setup.sh && bash /tmp/deuna-setup.sh && rm /tmp/deuna-setup.sh
```

> **Windows:** abre WSL y ejecuta el mismo comando.

El instalador te guía paso a paso:

1. Elige la tecnología (React Native, Angular, o todas)
2. Elige los skills que quieres instalar
3. Confirma la ruta de tu proyecto

No necesitas clonar el repo — solo descarga los skills que elegiste.

---

## Actualizar skills

Re-ejecuta el mismo comando desde tu proyecto:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/monorepo-skills/main/setup.sh | bash
```

---

## Agregar un skill nuevo

```bash
# Clona el repo (solo para contribuir)
git clone git@github.com:YOUR_ORG/monorepo-skills.git
cd monorepo-skills

# Crea el skill
./scripts/create-skill.sh react-native rn-animations

# Valida el frontmatter
npm run validate

# Commit y push — disponible para todos inmediatamente
```

---

## Comandos para contribuidores

```bash
npm run validate                      # valida todos los SKILL.md
npm run new react-native rn-nombre    # crea un skill nuevo desde el template
npm run new angular ng-nombre
npm run new generic mi-skill
```

---

## Estructura del repo

```
monorepo-skills/
├── setup.sh                          ← instalador (curl, no clonar)
├── scripts/
│   ├── validate-skills.sh
│   └── create-skill.sh
└── skills/
    ├── react-native/
    │   ├── rn-no-rerenders/SKILL.md
    │   └── rn-solid-dry-kiss/SKILL.md
    ├── angular/
    │   ├── ng-no-rerenders/SKILL.md
    │   └── ng-solid-dry-kiss/SKILL.md
    └── generic/
        └── skill-creator/
            ├── SKILL.md
            └── assets/SKILL-TEMPLATE.md
```
