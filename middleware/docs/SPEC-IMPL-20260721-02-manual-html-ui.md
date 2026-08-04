# SPEC-IMPL-20260721-02 — Manual HTML integrado en UI

**ID:** SPEC-IMPL-20260721-02
**Fecha:** 2026-08-04
**Estado:** Listo para delegación
**Agente ejecutor:** SOFIA
**Validación:** GEMINI

---

## 1. Objetivo

Convertir el manual de usuario actual (`docs/MANUAL_USUARIO.md`) en una **vista HTML accesible desde el menú principal** del middleware, para que el usuario (Ing. Francisco Aguirre) pueda consultarlo en cualquier momento sin salir del software.

---

## 2. Archivos existentes a reutilizar

- `docs/MANUAL_USUARIO.md` (320 líneas) — manual en Markdown ya redactado
- `docs/screenshots/01-dashboard.png` (51 KB)
- `docs/screenshots/02-configuracion.png` (109 KB)
- `docs/screenshots/03-acciones.png` (41 KB)
- `docs/screenshots/04-logs.png` (37 KB)
- `docs/screenshots/05-diagnostico.png` (62 KB)

**NO reescribir el manual.** Solo convertir el Markdown a HTML y crear la integración en la UI.

---

## 3. Decisiones técnicas (NO cambiar)

| Aspecto | Decisión |
|---------|----------|
| **Ruta de la página** | `GET /docs` (manual) y `GET /docs/:section` (anclas) |
| **Template engine** | Usar el mismo que las otras vistas (HTMX + HTML estático, ver `src/ui/views/*.html`) |
| **Estilos** | Tailwind CSS vía CDN (mismo que el resto de la UI) |
| **Markdown → HTML** | Script Node.js que use la lib `marked` (instalar como devDependency) |
| **Autenticación** | Requiere Basic Auth (igual que el resto del UI) |
| **Link en menú** | Agregar entre "Diagnóstico" y el final (o donde mejor quede) |

---

## 4. Estructura de archivos a crear/modificar

```
middleware/
├── docs/
│   ├── MANUAL_USUARIO.md        ← ya existe (NO modificar)
│   ├── MANUAL_USUARIO.html      ← NUEVO (HTML renderizado, se sirve estático)
│   └── screenshots/             ← ya existe (NO modificar)
├── scripts/
│   ├── build-docs.ts            ← NUEVO: convierte .md → .html
│   └── (copia el HTML a dist/docs/ durante el build)
├── src/ui/
│   ├── server.ts                ← MODIFICAR: agregar ruta GET /docs
│   └── views/
│       └── layout.html          ← MODIFICAR: agregar link "Documentación" en nav
└── package.json                 ← MODIFICAR: agregar "marked" como devDependency, agregar script "build:docs"
```

---

## 5. Implementación detallada

### 5.1 `package.json` — agregar dependencia y script

Agregar a `devDependencies`:
```json
"marked": "^12.0.0"
```

Agregar a `scripts`:
```json
"build:docs": "tsc scripts/build-docs.ts && node scripts/build-docs.js",
"build": "tsc -p tsconfig.build.json && node scripts/copy-views.cjs && node scripts/build-docs.js"
```

(El script `build` ahora también genera la documentación HTML.)

### 5.2 `scripts/build-docs.ts` — convertir Markdown a HTML

```typescript
import { marked } from 'marked';
import * as fs from 'node:fs';
import * as path from 'node:path';

const SOURCE = path.resolve('docs/MANUAL_USUARIO.md');
const OUTPUT = path.resolve('docs/MANUAL_USUARIO.html');

const md = fs.readFileSync(SOURCE, 'utf-8');
const html = marked.parse(md, { gfm: true });

// Envolver en HTML completo con estilos básicos inline
const styled = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>Manual de Usuario - Valueflow</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
           max-width: 900px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
    h1 { color: #009999; border-bottom: 2px solid #009999; padding-bottom: 8px; }
    h2 { color: #009999; margin-top: 32px; border-left: 4px solid #009999; padding-left: 12px; }
    h3 { color: #555; margin-top: 24px; }
    img { max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1); display: block; margin: 20px auto; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: 'Courier New', monospace; }
    pre { background: #f4f4f4; padding: 12px; border-radius: 6px; overflow-x: auto; }
    table { border-collapse: collapse; width: 100%; margin: 16px 0; }
    th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
    th { background: #f4f4f4; }
    blockquote { border-left: 4px solid #009999; margin: 16px 0; padding: 0 16px; color: #666; }
    a { color: #009999; text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    hr { border: none; border-top: 1px solid #ddd; margin: 24px 0; }
    .badge { display: inline-block; padding: 2px 8px; background: #009999; color: white; border-radius: 3px; font-size: 12px; }
  </style>
</head>
<body>
${html}
</body>
</html>`;

fs.writeFileSync(OUTPUT, styled, 'utf-8');
console.log(`✓ Generated ${OUTPUT}`);
```

### 5.3 `scripts/copy-views.cjs` — agregar copia de docs

Modificar `copy-views.cjs` para también copiar `docs/MANUAL_USUARIO.html` a `dist/docs/`:

```js
const fs = require('node:fs');
const path = require('node:path');

// Copiar vistas
const viewsSource = path.resolve('src/ui/views');
const viewsDest = path.resolve('dist/ui/views');
fs.cpSync(viewsSource, viewsDest, { recursive: true });

// Copiar docs (manual HTML)
const docsSource = path.resolve('docs/MANUAL_USUARIO.html');
const docsDestDir = path.resolve('dist/docs');
const docsDest = path.resolve('dist/docs/MANUAL_USUARIO.html');
if (fs.existsSync(docsSource)) {
  fs.mkdirSync(docsDestDir, { recursive: true });
  fs.cpSync(docsSource, docsDest);
}
```

### 5.4 `src/ui/server.ts` — agregar ruta `/docs`

Agregar después de las rutas existentes:

```typescript
import * as path from 'node:path';
import * as fs from 'node:fs';

// ... código existente ...

// Ruta para servir el manual HTML
app.get('/docs', (req, res) => {
  const manualPath = path.resolve('docs/MANUAL_USUARIO.html');
  if (fs.existsSync(manualPath)) {
    res.sendFile(manualPath);
  } else {
    res.status(404).send('Manual no encontrado. Ejecute npm run build:docs');
  }
});
```

### 5.5 `src/ui/views/layout.html` — agregar link en nav

Buscar la sección del menú de navegación (probablemente un `<nav>` con links a Dashboard, Configuración, etc.) y agregar:

```html
<a href="/docs" class="...">Documentación</a>
```

**El estilo debe coincidir con los otros links del menú** (mismo color, padding, hover). Usar las mismas clases CSS que usan los otros links en ese archivo.

### 5.6 Verificación final

Después de la implementación, verificar:
- [ ] `npm install` instala `marked`
- [ ] `npm run build:docs` genera `docs/MANUAL_USUARIO.html`
- [ ] `npm run build` incluye el manual en `dist/docs/`
- [ ] El middleware sirve `GET /docs` con HTTP 200 y el HTML
- [ ] La página muestra los 5 screenshots correctamente
- [ ] El link en el menú navega a `/docs`
- [ ] El manual requiere autenticación (igual que el resto)

---

## 6. Lo que NO incluir

- ❌ NO reescribir el contenido del manual (ya está bien redactado)
- ❌ NO agregar secciones nuevas al manual
- ❌ NO usar un framework nuevo (mantener HTML estático + Tailwind CDN)
- ❌ NO crear un servidor de docs separado (es solo una ruta más)
- ❌ NO hacer público el manual sin auth (debe mantener Basic Auth)

---

## 7. Validación esperada

```bash
# Después de la implementación
cd /mnt/Datos/Proyectos 2.0/PC/repaga-siemens/middleware
npm install
npm run build

# Verificar que el archivo HTML se generó
ls -la docs/MANUAL_USUARIO.html dist/docs/MANUAL_USUARIO.html

# Verificar que el middleware sirve el manual
curl -s -o /dev/null -w "Status: HTTP %{http_code}\n" -u admin:demo1234 http://127.0.0.1:4567/docs
# Debe devolver 200
```

---

## 8. Reporte esperado de SOFIA

```markdown
## Reporte SOFIA — Manual HTML en UI

### Estado: [COMPLETO / COMPLETO_CON_OBS / INCOMPLETO]

### Archivos creados/modificados:
- [lista]

### Validaciones:
- npm install: [OK/FAIL]
- npm run build:docs: [OK/FAIL]
- npm run build: [OK/FAIL]
- GET /docs responde 200: [OK/FAIL]
- Manual se ve correctamente: [OK/FAIL]
- Link en menú funciona: [OK/FAIL]

### Self-Review:
[respuestas]

### Observaciones:
[cualquier caveat]
```

---

*SPEC preparada por INTEGRA — ID: SPEC-IMPL-20260721-02*
*Pendiente: OK del usuario para delegar a SOFIA*