# SPEC-INFRA-20260721-01 — CI/CD para Valueflow Middleware

**ID:** SPEC-INFRA-20260721-01
**Padre:** [PROYECTO.md](../../../mnt/Datos/Proyectos%202.0/PC/repaga-siemens/PROYECTO.md)
**Fecha:** 2026-07-21
**Estado:** Listo para ejecución
**Agente ejecutor:** SOFIA
**Validación:** GEMINI (auditor de calidad)

---

## 1. Objetivo

Implementar **3 workflows de GitHub Actions** que automaticen:

1. **CI** — Validar código en cada push/PR (typecheck, lint, tests, build)
2. **Build Installer** — Compilar el instalador `.exe` de Windows usando Wine + Inno Setup
3. **Release** — Crear GitHub Releases con el `.exe` adjunto cuando se pushea un tag

---

## 2. Contexto del proyecto

- **Repo:** `https://github.com/frank-vcorp/Valueflow`
- **Rama principal:** `main`
- **Estructura actual:**
  ```
  Valueflow/
  ├── installer/
  │   ├── install.ps1
  │   ├── install.bat
  │   ├── installer.iss
  │   ├── build-installer.sh      ← Script ya existe, debe ejecutarse en CI
  │   └── README.md
  ├── middleware/                 ← Código Node.js/TypeScript
  ├── assets/                      ← Logos
  ├── proposals/, analysis/, specs/, checkpoints/
  ├── .github/                     ← (VACÍO - SOFIA debe crear workflows aquí)
  ├── README.md
  ├── PROYECTO.md
  └── .gitignore
  ```

**Stack:**
- Middleware: Node.js 20 LTS + TypeScript 5 + Express + Vitest + ESLint
- Instalador: Inno Setup 6.4.2 compilado vía Wine en Linux

---

## 3. Estructura a crear

```
.github/
└── workflows/
    ├── ci.yml                    ← Validación de código (lint, typecheck, tests)
    ├── build-installer.yml       ← Compila .exe con Wine + Inno Setup
    ├── release.yml               ← Crea GitHub Release con tag
    └── README.md                 ← Documentación de los workflows
```

---

## 4. Requisitos por workflow

### 4.1 `ci.yml` — Validación continua

**Triggers:**
- `push` a `main`
- `pull_request` a `main`

**Jobs:**

#### Job 1: `validate-middleware` (en `ubuntu-latest`)
Pasos:
1. `actions/checkout@v4`
2. `actions/setup-node@v4` con Node 20 + caché npm usando `middleware/package-lock.json`
3. `npm ci` en `middleware/`
4. `npx tsc --noEmit` (typecheck estricto)
5. `npx eslint .` (continuar si hay warnings, no fallar)
6. `npm run build` (compilar TypeScript)
7. `npm test -- --run` (correr tests de Vitest)

#### Job 2: `validate-installer` (en `ubuntu-latest`)
Pasos:
1. `actions/checkout@v4`
2. Validar sintaxis de `installer/install.ps1` con `[System.Management.Automation.Language.Parser]::ParseInput()` (instalar pwsh si falta: `sudo apt-get install -y powershell`)
3. Validar sintaxis bash de `installer/build-installer.sh` con `bash -n`
4. Verificar que las rutas en `installer/installer.iss` apunten a archivos que existen

#### Job 3: `security-scan` (opcional, `continue-on-error: true`)
Pasos:
1. `actions/checkout@v4`
2. `aquasecurity/trivy-action@master` con `scan-type: fs`, `scan-ref: middleware`, `severity: CRITICAL,HIGH`
3. `actions/upload-artifact@v4` con `trivy-fs-report.txt`

### 4.2 `build-installer.yml` — Compilación del instalador .exe

**Triggers:**
- `push` a `main` con cambios en `installer/**`, `middleware/**`, o `assets/**`
- `workflow_dispatch` con input opcional `release: boolean`

**Variables de entorno:**
- `INNO_SETUP_VERSION: "6.4.2"`

**Permisos:**
- `contents: write` (para crear releases si se solicita)

**Job único: `build-installer` (en `ubuntu-latest`)**

Pasos detallados:

#### 1. Checkout
```yaml
- uses: actions/checkout@v4
```

#### 2. Instalar Wine
```bash
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y wine64 wine32 xvfb cabextract
wine --version
```

#### 3. Descargar Inno Setup portable
```bash
mkdir -p /tmp/innosetup
cd /tmp/innosetup
wget -q "https://jrsoftware.org/download.php/is.exe" -O innosetup.exe
```

#### 4. Instalar Inno Setup silenciosamente
```bash
export WINEPREFIX=/tmp/.wine-installer
export WINEARCH=win32
export WINEDEBUG=-all
Xvfb :99 -screen 0 1024x768x16 &
export DISPLAY=:99
sleep 2
wine innosetup.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /DIR="C:\\InnoSetup"
ISCC=$(find ~/.wine/drive_c/ -name "ISCC.exe" 2>/dev/null | head -1)
# Verificar que existe, fallar si no
```

#### 5. Verificar estructura
```bash
[ -d "middleware" ] || exit 1
[ -d "assets" ] || exit 1
[ -f "installer/installer.iss" ] || exit 1
```

#### 6. Compilar con ISCC
```bash
cd installer
wine "$ISCC" installer.iss 2>&1 | tail -30
```

#### 7. Verificar .exe generado
```bash
EXE_FILE="installer/output/Valueflow-Setup-1.0.exe"
[ -f "$EXE_FILE" ] || exit 1
# Verificar header PE (bytes 4d5a = "MZ")
head -c 2 "$EXE_FILE" | xxd -p | grep -q "4d5a"
```

#### 8. Subir artifact
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: Valueflow-Setup-1.0-windows
    path: installer/output/Valueflow-Setup-1.0.exe
    if-no-files-found: error
    retention-days: 30
```

#### 9. Crear Release (opcional, solo si `inputs.release == true`)
```yaml
- if: github.event_name == 'workflow_dispatch' && inputs.release == true
  uses: softprops/action-gh-release@v2
  with:
    files: installer/output/Valueflow-Setup-1.0.exe
    generate_release_notes: true
    body: |
      ## Valueflow Middleware - Instalador para Windows
      ...
```

### 4.3 `release.yml` — Release automático por tag

**Triggers:**
- `push` de tags con formato `v*.*.*` (ej: `v1.0.0`, `v1.2.3`)

**Permisos:**
- `contents: write`

**Job único: `build-and-release`**
```yaml
uses: ./.github/workflows/build-installer.yml
with:
  release: true
secrets: inherit
```

### 4.4 `README.md` en `.github/workflows/`

Documentación que incluya:
- Descripción de cada workflow
- Tabla de triggers
- Outputs de cada uno
- Cómo usar `workflow_dispatch` manualmente
- Cómo crear un release (`git tag v1.0.0 && git push origin v1.0.0`)
- Diagrama ASCII del flujo
- Tips de mantenimiento

---

## 5. Decisiones técnicas (NO cambiar)

| Decisión | Justificación |
|----------|---------------|
| **`ubuntu-latest` para build** | Wine solo corre en Linux como runner |
| **Wine 32-bit para Inno Setup** | Inno Setup 6.x solo es 32-bit |
| **Xvfb para Wine headless** | Inno Setup necesita display virtual en CI |
| **Inno Setup v6.4.2** | Versión LTS probada, compatible con Wine |
| **`continue-on-error` solo en `security-scan`** | CI estricto; build separado |
| **Artifact retention 30 días** | Suficiente para releases típicas |
| **No compilar .exe en commits directos** | Solo cuando se solicita o en tags |
| **`npm ci` no `npm install`** | Builds reproducibles en CI |

---

## 6. Validaciones obligatorias

### 6.1 Estructural
- [ ] `.github/workflows/` contiene 4 archivos: `ci.yml`, `build-installer.yml`, `release.yml`, `README.md`
- [ ] Ningún archivo en `.github/` se commitea con secretos
- [ ] Los workflows referencian archivos que existen en el repo

### 6.2 Sintaxis
- [ ] `yamllint .github/workflows/*.yml` sin errores
- [ ] `actionlint .github/workflows/*.yml` sin errores (instalar via `npm install -g actionlint`)
- [ ] Cada `uses:` apunta a versiones con tag (ej: `@v4`, no `@main`)

### 6.3 Funcional (a verificar localmente con `act` si es posible)
- [ ] `act -j validate-middleware` corre sin errores
- [ ] El YAML es parseable por GitHub Actions

### 6.4 Seguridad
- [ ] No hay secretos hardcodeados
- [ ] Los permisos son mínimos (`contents: read` por defecto, `write` solo si necesario)
- [ ] `actions/checkout` usa siempre `@v4` (no SHA flotante)

---

## 7. Self-Review (OBLIGATORIO)

Antes de reportar como listo:

```markdown
## Self-Review SOFIA

### Estructura
- [ ] ¿Los 4 archivos están creados y commiteados?
- [ ] ¿Los paths en los workflows son correctos?
- [ ] ¿Las versiones de actions son tags fijos, no @main?

### Sintaxis
- [ ] ¿yamllint pasa sin errores?
- [ ] ¿actionlint pasa sin errores?

### Triggers
- [ ] ¿CI se ejecuta en push y PR?
- [ ] ¿Build solo cuando hay cambios en installer/middleware/assets?
- [ ] ¿Release solo en tags v*.*.*?

### Seguridad
- [ ] ¿No hay secretos en el código?
- [ ] ¿Permisos mínimos?
- [ ] ¿Trivy configurado con severity crítico/alto?

### Funcional
- [ ] ¿El artifact se sube correctamente?
- [ ] ¿El release se crea con la nota apropiada?
```

---

## 8. NO incluir

- ❌ No crear el `.exe` y commitearlo al repo (debe ser solo artifact)
- ❌ No usar `@main` en versions de actions (usar tags como `@v4`)
- ❌ No hacer `npm install` (usar `npm ci` para reproducibilidad)
- ❌ No usar Docker (más complejo, no aporta valor aquí)
- ❌ No crear Dependabot (eso es otra tarea separada)

---

## 9. Entregables

1. `.github/workflows/ci.yml` (validación de código)
2. `.github/workflows/build-installer.yml` (compilación de .exe)
3. `.github/workflows/release.yml` (release por tag)
4. `.github/workflows/README.md` (documentación)
5. Commit en `main` con mensaje: `ci: add GitHub Actions workflows for CI, build, and release`

---

## 10. Comando de prueba local (opcional)

Si SOFIA tiene `act` instalado (https://github.com/nektos/act):

```bash
# Probar el job de validación
cd /mnt/Datos/Proyectos 2.0/PC/repaga-siemens
act -j validate-middleware

# Probar el build (puede tardar varios minutos)
act -j build-installer --secret GITHUB_TOKEN=token_falso
```

Si `act` no está disponible, validar al menos con `yamllint` y `actionlint`.

---

## 11. Reporte final

SOFIA debe reportar con este formato:

```markdown
## Reporte SOFIA — CI/CD Implementation

### Estado: [COMPLETO / COMPLETO_CON_OBS / INCOMPLETO]

### Archivos creados:
- [lista de archivos con líneas]

### Validaciones ejecutadas:
- yamllint: [OK/FAIL]
- actionlint: [OK/FAIL]
- npm ci: [OK/FAIL]
- npm test: [OK/FAIL]
- npm run build: [OK/FAIL]

### Self-Review:
[respuestas a las preguntas]

### Observaciones:
- Si se usó act para probar, indicar resultado
- Cualquier caveat sobre el build con Wine

### Commit:
- [hash del commit]
- [URL del commit en GitHub]
```

---

*SPEC preparada por INTEGRA — ID: SPEC-INFRA-20260721-01*
*Pendiente: OK del usuario para delegar a SOFIA*