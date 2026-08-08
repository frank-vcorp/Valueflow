# Handoff VM Sesión 2026-08-07 — Valueflow Middleware v2.0.11

**Sesión:** 2026-08-07 (13:00 CST) — Frank migró a VSCode en VM Windows 11 para iteración más rápida
**Estado del lote:** `lote-ventas-20260805-01` vigente hasta 2026-08-07T23:59 (~11h)
**Working tree:** `C:\Users\frank\...` (en VM, NO commiteado todavía)
**Repo Linux:** `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens`

---

## 🎯 Objetivo de esta sesión

Frank instaló VSCode en la VM Windows 11 para iterar más rápido (sin scp/USB). El estado es:

- **v2.0.11 self-contained** compilado en Linux (108 MB .exe, 34 MB bundle)
- **F1 fix** aplicado: `ecosystem.config.js` sin `wait_ready`
- **`node_modules` pre-instalado** dentro del bundle (no requiere `npm install` en VM con internet)
- **`fbclient.dll`** opcional (decisión Frank: Aspel SAE 10 tiene la suya)

---

## 📦 Artefactos listos para copiar a VM

| Archivo | Path Linux | SHA256 | Tamaño |
|---------|-----------|--------|--------|
| Instalador .exe | `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens/installer/build_output/Valueflow-Setup-v2.0.11.exe` | `9cd94a3d56e605107641cb14dbff3e66c36cb465510e6e8b2b0b828a6329038c` | 108 MB |
| Bundle .zip | `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens/dist-pkg/valueflow-middleware-v2.0.11.zip` | `9fbaf76b733d6c8c90a97b8497d4bdd5bf183a10a23306badc80615aa820cbab` | 34 MB |

---

## 🧹 Paso 1 — Limpieza total VM (PowerShell Admin, uno a uno)

```
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

```
pm2 kill
```

```
pm2 delete all 2>$null
```

```
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force
```

```
Start-Sleep -Seconds 2
```

```
Get-Process node -ErrorAction SilentlyContinue
```

```
netstat -an | findstr :4567
```

```
Remove-Item -Recurse -Force "C:\Program Files\siemens-middleware" -ErrorAction SilentlyContinue
```

```
Remove-Item -Recurse -Force "C:\apps\siemens-middleware" -ErrorAction SilentlyContinue
```

```
Remove-Item -Recurse -Force "C:\Temp\valueflow-middleware" -ErrorAction SilentlyContinue
```

```
Remove-Item -Recurse -Force "$env:USERPROFILE\Desktop\Valueflow Middleware.lnk" -ErrorAction SilentlyContinue
```

```
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Valueflow Middleware",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Valueflow Middleware"
)
foreach ($reg in $regPaths) {
    if (Test-Path $reg) { Remove-Item -Path $reg -Force -ErrorAction SilentlyContinue }
}
```

```
Test-Path "C:\Program Files\siemens-middleware"
```

```
Test-Path "C:\apps\siemens-middleware"
```

```
Get-Process node -ErrorAction SilentlyContinue
```

```
netstat -an | findstr :4567
```

**Esperado:** los últimos 4 comandos devuelven `False` o vacío.

---

## 📥 Paso 2 — Copiar .exe a VM

Con VSCode en VM, lo más práctico es **compartir carpeta del host Linux** (o usar la integración nativa de VSCode si tiene Remote SSH). Si NO, opciones:

1. **USB:** copiar el `.exe` a USB desde Linux, conectar a VM, copiar a `C:\Users\frank\Downloads\`
2. **Carpeta compartida VirtualBox:** configurar shared folder si usás VirtualBox
3. **scp/SSH server en VM:** si instalaste OpenSSH en Windows
4. **Servidor HTTP temporal en Linux:** `python3 -m http.server 8080` en `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens/installer/build_output/`, descargar desde VM con `Invoke-WebRequest`

---

## 🚀 Paso 3 — Ejecutar instalador

Doble click en `Valueflow-Setup-v2.0.11.exe` (o ejecutar desde PowerShell Admin):

```
cd "C:\Users\frank\Downloads"
.\Valueflow-Setup-v2.0.11.exe
```

**Wizard:**
1. Welcome → Next
2. Select Destination → **Next** (default `C:\Program Files\siemens-middleware`)
3. Seleccionar ruta `.FDB` → Browse → `C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB` → Next
4. Ready to install → **Install**

**Esperado (sin errores):**
- PASO 1/8: Welcome
- PASO 2/8: Verificar Windows 10/11 x64 ✅
- PASO 3/8: Verificar Firebird 2.5+ ✅ (WARN si no encuentra fbclient.dll — OK porque usamos node-firebird JS puro)
- PASO 4/8: Instalar VC++ Redistributable ✅ (ya estaba)
- PASO 5/8: Instalar Node.js 20 LTS (MSI) ✅ (ya estaba)
- PASO 6/8: Extraer middleware del bundle ✅ **+ log "Instalación in-place detectada, saltando copia"**
- PASO 7/8: npm install (dependencias) ✅ **+ log "node_modules restaurado desde bundle.zip" (NUEVO en v2.0.11)**
- PASO 8/8: Configurar .env + arrancar servicio ✅
  - bcrypt hash validado (B1 fix)
  - FIREBIRD_PASSWORD=MASTERKEY (B4 fix, decisión Frank)
  - .env configurado
  - config.json configurado
  - PM2 instalado
  - dist/index.js verificado
  - **Acceso directo en escritorio creado**
  - **INSTALACION COMPLETADA EXITOSAMENTE**

---

## ⚠️ Warnings conocidos en PASO 8 (NO críticos)

```
[WARN] Salida delete: El nombre de archivo, el nombre de directorio o la sintaxis de la etiqueta del volumen no son correctos.
[WARN] Salida start: El nombre de archivo, el nombre de directorio o la sintaxis de la etiqueta del volumen no son correctos.
[WARN] Estado del servicio desconocido - revisar manualmente
```

Estos warnings son por **paths con espacios** en PowerShell + `cmd /c` (bug histórico, mismo v2.0.8). **El servicio SÍ queda corriendo** pero el instalador no lo verifica correctamente. Por eso **SIEMPRE** hay que hacer la verificación manual del Paso 4.

---

## ✅ Paso 4 — Verificación post-instalación

```
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

```
Get-Process node -ErrorAction SilentlyContinue
```

```
netstat -an | findstr :4567
```

```
pm2 list
```

**Esperado:**
- `Get-Process node` → muestra 1 proceso Node (~37 MB)
- `netstat` → `TCP 127.0.0.1:4567 LISTENING`
- `pm2 list` → `siemens-middleware | online | cpu >0% | mem 30-50 MB`

**Si PM2 quedó vacío o `netstat` muestra puerto cerrado** (caso conocido v2.0.11 antes del fix v2.0.12), arrancar manual:

```
Set-Location "C:\apps\siemens-middleware\middleware"
```

```
Get-Content ecosystem.config.js
```

**Esperado:**
```js
module.exports = {
  apps: [{
    name: 'siemens-middleware',
    script: 'dist/index.js',
    cwd: __dirname,
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    listen_timeout: 5000,
    env: { NODE_ENV: 'production' }
  }]
};
```

**NO debe tener `wait_ready: true`** (F1 fix aplicado en v2.0.11).

```
pm2 start ecosystem.config.js
```

```
Start-Sleep -Seconds 5
```

```
pm2 list
```

```
netstat -an | findstr :4567
```

---

## 🌐 Paso 5 — Probar UI

```
Start-Process "http://localhost:4567/"
```

**Login:**
- User: `Admin`
- Password: `Admin123`

**Pantallas a validar:**
1. Dashboard principal (status cards: Inventario, Ventas)
2. Menú Configuración (cambiar API Key Siemens si tenés la real)
3. Menú Diagnósticos (debe mostrar "Driver: node-firebird (JS puro, sin compilacion nativa)" en línea 99 de server.ts)
4. Endpoint `/api/health` o `/health` responde 200

---

## 🐛 Si algo falla

### Capturar logs

```
pm2 logs siemens-middleware --lines 100 --nostream --raw 2>&1 | Out-File -FilePath "C:\apps\siemens-middleware\pm2-debug.log" -Encoding UTF8
```

```
Get-Content "C:\apps\siemens-middleware\logs\install.log"
```

```
Get-Content "C:\Users\frank\.pm2\logs\siemens-middleware-error-0.log"
```

### Errores comunes

| Error | Causa | Fix |
|-------|-------|-----|
| `ERR_CONNECTION_REFUSED` | PM2 no bindeó puerto | Verificar `wait_ready` no esté en ecosystem.config.js (F1 fix v2.0.11) |
| `Credenciales inválidas` | Hash bcrypt no es de Admin123 | B1 fix v2.0.9 lo valida. Si pasa, regenerar: `node -e "console.log(require('bcryptjs').hashSync('Admin123', 12))"` y pegar al `.env` |
| `node-gyp` / Python errors | install.ps1 sin `--ignore-scripts` | v2.0.11 lo tiene. Si pasa, verificar `install.ps1:323` |
| `Could not locate the bindings file` | Firebird fbclient.dll no accesible | NO BLOQUEANTE para UI. Solo afecta queries a BD. Verificar que `C:\Windows\System32\fbclient.dll` exista |
| PM2 slot zombi (online pid 3400 pero puerto cerrado) | PM2 no limpió slot tras crash | `pm2 kill` + `pm2 delete all` + `pm2 start ecosystem.config.js` |

---

## 📊 Estado del lote `lote-ventas-20260805-01`

| Ticket | Estado | Notas |
|--------|--------|-------|
| FACT-20260805-01 | ✅ DONE | 46,430 facturas |
| FACT-20260805-02 | ✅ DONE | CFDI_32700 → QUA status 201 |
| FIX-20260805-01 | ✅ DONE | firebird concurrency |
| IMPL-20260806-01 | ✅ DONE | 8 fixes QA Gemini |
| **MR-20260806-01** (instalación limpia VM) | 🟡 EN VALIDACIÓN | Workaround A funcionó parcialmente, v2.0.11 + F1 fix pendiente |
| **MR-20260806-02** (instalador v2.0.9-11) | ⏳ EN PROGRESO | SOFIA entregó v2.0.11 self-contained, Frank prueba E2E en VM |

---

## 🔧 Cambios acumulados en working tree (sin commitear)

**IMPL-20260807-01 (v2.0.9):** 8 fixes
- `installer/install.ps1` (B1 bcrypt, B2 username, B3 LOG_DIR, B4 FIREBIRD_PASSWORD, B5 auto-build, H1 in-place, H6 wizard .ini, H7 devDeps)
- `installer/installer.iss` (H2 .env exclude, B6 path unified, H9 versionado)
- `installer/prepare-dist-pkg.sh` (B5 pre-build)
- `installer/VERSION` (H9)
- `installer/uninstall.bat` (H8)
- `middleware/ecosystem.config.js` (B7 cwd __dirname, B8 sin health_check, H4 wait_ready+listen_timeout)
- `installer/build_output/Valueflow-Setup-v2.0.10.exe` (76 MB, superseded)

**IMPL-20260807-02 (v2.0.10):** 5 cambios
- `installer/install.ps1` (--ignore-scripts)
- `middleware/package.json` (4 deps nativas fuera)
- `middleware/src/ui/server.ts:99` (string driver)
- `installer/installer.iss` (bump v2.0.10)
- `installer/VERSION` (PATCH=10)

**IMPL-20260807-03 (v2.0.11):** 6 cambios
- `middleware/ecosystem.config.js` (F1 fix: sin wait_ready)
- `installer/prepare-dist-pkg.sh` (npm install + slim)
- `installer/install.ps1` (self-contained + Expand-Archive fallback)
- `installer/installer.iss` (bump v2.0.11 + bundle.zip dentro del .exe)
- `installer/VERSION` (PATCH=11)

---

## 📞 Cuando termines de probar

Reportá a ATLAS con:

1. **Salida de los 4 comandos del Paso 4** (`Get-Process node`, `netstat :4567`, `pm2 list`, opcional `pm2 logs`)
2. **Captura del login en navegador** (qué ves después de Admin/Admin123)
3. **Si FALLA algo**, pegame el log completo (`install.log`, `pm2-error-0.log`)

**Si TODO funciona** → INTEGRA coordina commit + push (F4 del audit GEMINI: incluir `uninstall.bat` y `bump-version.sh`, agregar `installer/build_output/` a `.gitignore`).

---

## 🔗 Referencias cruzadas

- Bitácora sesión 2026-08-05/06: `analysis/BITACORA_SESION_20260806.md`
- Dictamen DEBY previo: `context/interconsultas/DICTAMEN_FIX-20260806-01.md`
- Reporte SOFIA v2.0.11: `context/interconsultas/IMPL-20260807-03-reporte.md`
- GEMINI audit v2.0.11: `context/interconsultas/QA-20260807-03-gemini.md`
- Handoff INTEGRA→SOFIA: `context/interconsultas/IMPL-20260807-03-handoff.md`

---

**Última actualización:** 2026-08-07 13:00 CST
**Lote expira:** 2026-08-07 23:59 (~11h)
**Sesión ATLAS-M3 retirada.** Quedo a la espera del reporte de Frank.