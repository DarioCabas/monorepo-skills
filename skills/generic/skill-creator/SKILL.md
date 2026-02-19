---
name: skill-creator
description: Creates new skills for monorepo-skills or improves existing ones following repo conventions. Trigger: When user wants to add a new skill, capture a workflow as a reusable skill, refine a SKILL.md, or validate skill structure and frontmatter.
license: Apache-2.0
metadata:
  author: deuna
  version: "2.0"
  scope: [generic]
  auto_invoke: "Creating new skills"
allowed-tools: Read, Write, Bash, Glob
---

# Skill Creator

> El skill que sabe cómo crear otros skills en este monorepo.
> Cubre el ciclo completo: captura de intención → draft → revisión → iteración → commit.

## Cuándo activar este skill

Claude debe activar este skill cuando:

- El usuario quiere "crear un nuevo skill", "agregar un skill al monorepo"
- El usuario quiere capturar un workflow existente como skill reutilizable
- El usuario quiere mejorar, refactorizar o validar un SKILL.md existente
- El usuario menciona "monorepo-skills" + "agregar" o "nuevo"
- El usuario quiere que un patrón de código que ya usa se convierta en skill

NO activar cuando:

- El usuario solo quiere usar un skill existente (eso es trabajo del skill en cuestión)
- El usuario pide crear código de aplicación (eso es trabajo de los skills de tecnología)

---

## Arquitectura del monorepo

Antes de crear cualquier skill, leer y entender la estructura:

```
monorepo-skills/
├── skills/
│   ├── react-native/     ← Skills específicos de React Native (prefijo: rn-)
│   ├── angular/          ← Skills específicos de Angular (prefijo: ng-)
│   └── generic/          ← Skills agnósticos de tecnología (prefijo: generic-)
│       └── skill-creator/ ← Este skill
│           ├── SKILL.md
│           └── assets/
│               └── SKILL-TEMPLATE.md   ← Template canónico
└── templates/
    └── _skill-template/  ← Template base original (no modificar)
```

**Regla de ubicación:**

- ¿El skill aplica solo a React Native? → `skills/react-native/`
- ¿El skill aplica solo a Angular? → `skills/angular/`
- ¿El skill aplica a cualquier tecnología o es meta (como este)? → `skills/generic/`

---

## Flujo de trabajo

```
1. Capturar intención      → Entender qué quiere hacer el usuario
2. Investigar contexto     → Leer skills existentes para no duplicar
3. Generar draft           → Usar SKILL-TEMPLATE.md como base
4. Revisar con el usuario  → Iterar sobre description, instrucciones, ejemplos
5. Validar estructura      → Checklist de calidad antes de guardar
6. Guardar en ubicación correcta → Crear el folder y archivos
7. Actualizar README.md    → Agregar el skill a la tabla principal
```

El usuario puede entrar en cualquier punto del flujo. Adaptar según contexto.

---

## Paso 1 — Capturar intención

Hacer las preguntas mínimas necesarias. No interrogar — inferir lo que se pueda.

**Preguntas clave (solo si no son evidentes del contexto):**

1. **¿Qué problema resuelve?** — "¿Qué quieres que Claude haga cuando use este skill?"
2. **¿Qué tecnología?** — react-native / angular / generic
3. **¿Hay un patrón existente que quieras capturar?** — Código ya escrito, workflow ya definido, decisiones de arquitectura tomadas

Si el usuario dice "quiero un skill para animaciones en RN", ya hay suficiente para arrancar.
Si el usuario pega código o describe un workflow detallado, extraer la intención de ahí.

---

## Paso 2 — Investigar contexto

```bash
# Listar skills existentes para detectar solapamiento
find skills/ -name "SKILL.md" | sort

# Leer skills de la misma tecnología para mantener consistencia de estilo
cat skills/react-native/rn-component-generator/SKILL.md
cat skills/angular/ng-component-generator/SKILL.md
```

Verificar:

- ¿Ya existe un skill similar? Si sí, ¿es mejor mejorar ese que crear uno nuevo?
- ¿El naming sigue la convención de prefijos del repo?
- ¿El scope es correcto? (No demasiado amplio, no demasiado estrecho)

---

## Paso 3 — Generar el draft

**Siempre leer el template antes de escribir:**

```bash
cat skills/generic/skill-creator/assets/SKILL-TEMPLATE.md
```

### Reglas críticas para el SKILL.md

#### `name` — el identificador único

```yaml
# ✅ Correcto
name: rn-animations
name: ng-reactive-forms
name: generic-git-commit

# ❌ Incorrecto
name: React Native Animations   # mayúsculas
name: rn_animations              # guión bajo
name: animations                 # sin prefijo de tecnología
```

#### `description` — el campo más importante

El modelo descubre cuándo usar el skill **solo** por este campo.

```yaml
# ❌ Demasiado vago — el skill nunca se activará
description: Helps with animations in React Native.

# ✅ Específico: QUÉ + CUÁNDO + palabras clave de trigger
description: >
  Create and optimize React Native animations using react-native-reanimated v3:
  layout animations, shared element transitions, gesture-driven interactions,
  and scroll-based animations. Use when adding motion to RN components, fixing
  jank in existing animations, or migrating from Animated API to Reanimated.
```

**Checklist del description:**

- [ ] Menciona QUÉ hace (acción + resultado)
- [ ] Menciona CUÁNDO usarlo (trigger conditions)
- [ ] Incluye palabras clave que el usuario mencionaría naturalmente
- [ ] Entre 80 y 300 caracteres en la descripción principal
- [ ] No genérico: "Helps with X" → malo. "Does X when Y happens" → bueno

#### `version` — siempre empezar en 1.0.0

```yaml
version: 1.0.0
```

#### `technology` — uno de los valores permitidos

```yaml
technology: react-native # | angular | generic
```

#### `allowed-tools` — solo si se necesita restricción

```yaml
# Si el skill solo necesita leer archivos (no escribir):
allowed-tools: Read, Grep, Glob

# Si el skill necesita leer y escribir:
allowed-tools: Read, Write, Bash, Glob

# Si no se especifica → Claude pide permiso normalmente (recomendado para skills nuevos)
```

---

### Estructura del contenido del SKILL.md

```markdown
# Nombre del Skill

> Una línea — qué hace, para quién.

## Cuándo activar este skill

[Condiciones específicas con palabras clave reales]

## Mental Model (si aplica a performance/arquitectura)

[El "por qué" antes de los patterns]

## Instrucciones

[Pasos numerados con código concreto ✅/❌]

## Anti-patterns

[Tabla: anti-pattern | problema | fix]

## Checklist de calidad

[Items específicos del dominio]

## Troubleshooting

[Tabla: problema | causa | solución]

## Version History

[Changelog]
```

**Principios del contenido:**

- **Código real, no pseudocódigo** — cada ejemplo debe ser copy-pasteable
- **✅/❌ en ejemplos** — siempre mostrar el incorrecto junto al correcto
- **Pasos imperativos** — "Genera el archivo X", no "El archivo X debe generarse"
- **Tablas para comparaciones** — anti-patterns, troubleshooting, mapeos de tokens
- **Sin introducciones genéricas** — arrancar directo con el contenido útil

---

## Paso 4 — Revisar con el usuario

Después de generar el draft, presentar:

1. El `name` y `description` propuestos — son lo más crítico
2. La estructura de secciones — confirmar que cubre todos los casos de uso
3. Un ejemplo concreto del skill en acción — muestra si la descripción funcionaría

Preguntar específicamente:

- "¿El description captura correctamente cuándo debería activarse?"
- "¿Falta algún anti-pattern común que deberíamos incluir?"
- "¿El nivel de detalle en las instrucciones es suficiente o es demasiado?"

---

## Paso 5 — Validar estructura

Antes de guardar, verificar este checklist:

```
YAML Frontmatter:
  [ ] name: solo minúsculas, números, guiones — max 64 chars
  [ ] description: incluye QUÉ + CUÁNDO + palabras clave — entre 80 y 1024 chars
  [ ] version: formato semver (1.0.0)
  [ ] technology: react-native | angular | generic
  [ ] El archivo empieza con --- en la línea 1
  [ ] El frontmatter cierra con --- antes del contenido Markdown

Contenido:
  [ ] Sin pseudocódigo — todo código es real y ejecutable
  [ ] Cada ejemplo incorrecto tiene su contraparte correcta (❌/✅)
  [ ] La sección "Cuándo activar" tiene condiciones específicas, no genéricas
  [ ] Si tiene anti-patterns: tabla completa con problema y fix
  [ ] Si es un skill de performance: tiene sección "Mental Model"
  [ ] Sin texto de relleno ni introducciones genéricas ("In this skill, we will...")

Naming:
  [ ] Prefijo correcto según tecnología (rn-, ng-, generic-)
  [ ] El folder name coincide exactamente con el campo 'name' del YAML
```

Para validar el YAML automáticamente:

```bash
./scripts/validate-skills.sh skills/[tech]/[skill-name]/SKILL.md
```

---

## Paso 6 — Guardar en la ubicación correcta

```bash
# Crear el folder del skill
mkdir -p skills/[technology]/[skill-name]/

# Si el skill tiene assets (templates, referencias):
mkdir -p skills/[technology]/[skill-name]/assets/

# Archivos mínimos:
# - SKILL.md (requerido)
# - examples.md (muy recomendado — ejemplos de prompts + output)
# - assets/ (opcional — templates, referencias adicionales)
```

El folder name **debe coincidir exactamente** con el campo `name` del YAML frontmatter.

```bash
# Verificar que el nombre del folder coincide con el name en el YAML
grep "^name:" skills/[technology]/[skill-name]/SKILL.md
# Output esperado: name: [skill-name]  ← idéntico al nombre del folder
```

---

## Paso 7 — Actualizar README.md

Agregar el nuevo skill a la tabla en `README.md`:

```markdown
| [technology] | `[skill-name]` | [descripción breve — una línea] |
```

También actualizar el mapa de skills en `scripts/install.sh` y `scripts/cli.js` si el skill debe estar disponible para instalación vía CLI.

---

## Cuándo crear un nuevo skill vs mejorar uno existente

| Situación                                            | Acción                                                |
| ---------------------------------------------------- | ----------------------------------------------------- |
| El skill existente cubre el 80%+ del caso nuevo      | Mejorar el existente — agregar sección o anti-pattern |
| El caso nuevo tiene un scope completamente diferente | Crear skill nuevo                                     |
| El skill existente es muy amplio y se puede dividir  | Proponer split al usuario antes de proceder           |
| El usuario pide explícitamente un skill nuevo        | Crear skill nuevo respetando su decisión              |

---

## Mejorar un skill existente

Si en lugar de crear uno nuevo, el objetivo es mejorar un skill existente:

```bash
# Leer el skill actual completo
cat skills/[tech]/[skill-name]/SKILL.md

# Identificar qué falta:
# - ¿Hay anti-patterns sin documentar?
# - ¿La descripción activa bien el skill o es vaga?
# - ¿Faltan ejemplos en examples.md?
# - ¿El mental model es claro o hay que mejorarlo?
```

Al mejorar: incrementar la version (1.0.0 → 1.1.0 para cambios menores, 2.0.0 para rewrites).
Agregar entrada al Version History documentando qué cambió y por qué.

---

## Ejemplos de skills bien construidos en este repo

Para tener referencia de calidad antes de escribir uno nuevo:

```bash
# Ejemplo de skill de performance con mental model
cat skills/react-native/rn-component-generator/SKILL.md

# Ejemplo de skill con HTML semántico y anti-patterns
cat skills/angular/ng-component-generator/SKILL.md

# Ejemplo de skill con patrones HTTP avanzados
cat skills/angular/ng-service-pattern/SKILL.md
```

---

## Anti-patterns al crear skills

| Anti-pattern                             | Problema                                            | Fix                                              |
| ---------------------------------------- | --------------------------------------------------- | ------------------------------------------------ |
| `description: Helps with X`              | Demasiado vago — el skill no se activa              | Especificar QUÉ hace + CUÁNDO + trigger words    |
| Skill demasiado amplio ("rn-everything") | Nunca se activa porque nada lo trigger precisamente | Dividir en skills focalizados                    |
| Pseudocódigo en ejemplos                 | Claude no puede usar los ejemplos directamente      | Código real y ejecutable siempre                 |
| Folder name ≠ YAML name                  | El skill no se carga correctamente                  | Verificar que ambos son idénticos                |
| Sin sección "Cuándo NO activar"          | Skill se activa en casos incorrectos                | Agregar contraejemplos de activación             |
| Un skill sin `version`                   | No hay forma de trackear cambios                    | Siempre empezar con `version: 1.0.0`             |
| `allowed-tools` demasiado permisivo      | Claude tiene acceso a más de lo necesario           | Solo listar las tools que el skill realmente usa |

---

## Version History

- v1.0.0 — Release inicial: flujo completo de creación, validación y ubicación
