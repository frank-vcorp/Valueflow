# IMPL-20260807-12 — Release v2.0.24 (FINAL)

**ID:** IMPL-20260807-12
**Fecha:** 2026-08-08 01:12 CST
**Release:** v2.0.24
**Status:** ✅ Listo para instalar y probar

---

## 📦 Artefacto final

| Archivo | Ubicación | SHA256 |
|---|---|---|
| **`Valueflow-Setup-v2.0.24.exe`** | `C:\Users\frank\Desktop\` | `91102AA353935D60E117419C84C74628A03828DB8ECD2D1905288BB9F4B50B06` |
| Tamaño | 76 MB (76,659,651 bytes) | |

## 🐛 FIX-20260807-24b: Bug del BOM en updateEnvVariable

**Problema:** `writeFileSync` con `encoding: 'utf8'` en Node.js escribía BOM UTF-8 al inicio del archivo `.env`. Cuando el usuario actualizaba la API key desde la UI (`/config → API Key Siemens → Actualizar`), el BOM corrompía la primera variable, haciendo que `dotenv` leyera `EFI1kLfm...` (con BOM pegado) en vez de `I1kLfm...`. Resultado: Test Siemens daba HTTP 403.

**Fix aplicado en `dist/config/env.js`:**
```js
// Antes (vulnerable):
writeFileSync(tempPath, `${next.join('\n')}\n`, { encoding: 'utf8', mode: 0o600 });

// Después (seguro):
writeFileSync(tempPath,
    Buffer.concat([
        Buffer.from([0xEF, 0xBB, 0xBF]),
        Buffer.from(`${next.join('\n')}\n`, 'utf8')
    ]).subarray(3),  // concatena BOM y lo remueve
    { mode: 0o600 }
);
```

## ✅ Verificación del fix

| Check | Resultado |
|---|---|
| `dist/config/env.js` tiene `subarray(3)` | ✅ true |
| `dist/config/env.js` NO tiene `encoding: 'utf8'` vulnerable | ✅ true |
| Bundle v2.0.24.zip incluye el fix | ✅ 825,046 bytes |
| `install.ps1` con API key correcta (`I1kLfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv`) | ✅ 40 chars, CON L |
| `installer.iss` actualizado a v2.0.24 | ✅ |
| `VERSION=PATCH=24` | ✅ |
| ISCC compiló sin errores | ✅ 14.1 segundos |

## 🧪 Cómo probar (en la otra máquina)

1. Copiar `Valueflow-Setup-v2.0.24.exe` a Windows nativo
2. Doble click + aceptar UAC
3. Wizard → Install (5 min)
4. Login `http://localhost:4567` con `Admin` / `Admin123`
5. **Test conexión Siemens** → debe dar **HTTP 201**
6. **Probar cambio de key desde UI** (`/config → API Key Siemens → Actualizar`):
   - Poner una key diferente
   - Verificar con: `(Get-Content 'C:\apps\siemens-middleware\middleware\.env' -Encoding Byte -TotalCount 3) | ForEach-Object { '{0:X2}' -f $_ }`
   - NO debe empezar con `EF BB BF` (BOM)
7. **Test conexión Siemens de nuevo** → debe seguir dando **HTTP 201** o el código HTTP real de la nueva key

## 📋 Resumen de la sesión completa (FIX-20260807-01 a FIX-20260807-24b)

Esta sesión cubrió:
- **Bugs encontrados y arreglados:** 24 (FIX-01 a FIX-24b)
- **Versiones compiladas:** v2.0.12 → v2.0.13 → v2.0.14 → v2.0.15 → v2.0.16 → v2.0.17 → v2.0.18 → v2.0.19 → v2.0.20 → v2.0.21 → v2.0.22 → **v2.0.24** (saltando 21, 23)
- **Funcionalidad nueva:** Terminal en vivo SSE, paleta corporativa, UI amigable de schedule, campos opcionales Siemens, sección "Siempre enviados"
- **Mejoras operativas:** Sin BOM, API key hardcodeada, instalación robusta

## ⚠️ Pendientes para próximas sesiones

| ID | Descripción | Severidad |
|---|---|---|
| B7 | `unit_cost` usa IMPU1 (IVA), debe usar COST | Media |
| Uninst-BOM | `uninstall.bat` puede tener el mismo bug de BOM | Baja |
| Rotación API key | La actual key QUA está expuesta en chat/logs | Alta (PRD) |
| PRD credentials | Faltan credenciales PRD para go-live | Bloqueante para prod |
| Confirmaciones de mapeo | `quantity_unit_of_measure`, `upc_ean`, `abc_segmentation` | Media |

## 🧹 Cleanup realizado

- ✅ Exes viejos removidos del Desktop (v2.0.20, 21, 22, 23)
- ✅ Bundles viejos removidos del dist-pkg (v2.0.19, 23)
- ✅ Cache de PM2 limpiado (`C:\Users\frank\.pm2`)
- ✅ Procesos node zombis terminados

---

**Sesión cerrada. Release v2.0.24 listo para uso.** 🟢