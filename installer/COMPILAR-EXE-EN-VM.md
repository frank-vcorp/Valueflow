# 🚀 Compilador .exe en VM Windows — versión final 2026-08-05

**Última actualización:** 2026-08-05 23:14 CST (tras validación E2E QUA 201 Created)

## Estado al cierre del lote `lote-ventas-20260805-01`

- ✅ **Inventario validado** en QUA con 8,169 productos
- ✅ **Ventas validadas** en QUA con factura CFDI_32700 (3 records, status=201)
- ✅ **Cron schedules validados** (auto-firing sin solapamiento)
- ✅ **FIX-20260805-01** aplicado: race condition del pool Firebird resuelto
- ✅ **Bundle regenerado**: `dist-pkg/valueflow-middleware-v1.0.zip` (448 KB, 79 archivos)

## Cambios aplicados al bundle (todos verificados)

| Cambio | Valor en bundle |
|--------|-----------------|
| `config.json::firebird.db_path` | `C:/Aspel/SAE90/BD/SAE90EMPRE01.FDB` (placeholder, instalador sobrescribe con autodetección) |
| `config.json::firebird.user` | `SYSDBA` |
| `config.json::siemens.api_key` | `env:SIEMENS_API_KEY` (literal, sin secretos en repo) |
| `.env::FIREBIRD_PASSWORD` | **Vacío** (instalador captura con `-Silent` o `Read-Host`) |
| `dist/jobs/runSales.js` | Default `new Date(Date.now() - 86_400_000)` (ayer) |
| `dist/db/queries/sales.js` | Mantiene fix `BETWEEN` rango día (mejora permanente) |
| `dist/db/firebird.js` | Mantiene FIX-20260805-01 (NO_WAIT, streaming, backoff, maxConnections=3) |

---

## Situación: Wine bloqueado, instalar en VM Windows directamente

- Bundle listo: `repaga-siemens/dist-pkg/valueflow-middleware-v1.0.zip` (448 KB, 79 archivos)
- Generar el `.exe` requiere **Inno Setup Compiler** corriendo en Windows
- Intentado: `sudo apt install wine` → FALLO (`sudo: A terminal is required to authenticate`)
- Solución: Compilar el `.exe` directamente en la VM Windows 11 del cliente (ya provisionada con Aspel SAE 9.0 + Firebird 2.5 instalado)

**Tiempo estimado:** 5-10 minutos.

---

## Pasos a ejecutar en la VM Windows 11 (cliente)

### 1. Instalar Inno Setup Compiler (1 min)

1. Abrir navegador en la VM
2. Ir a **https://jrsoftware.org/isdl.php**
3. Descargar **Inno Setup 6.x** (última estable)
4. Ejecutar instalador → Next → Next → Install (opciones por defecto OK)
5. Verificar instalación: `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` debe existir

### 2. Transferir el bundle a la VM (~30s)

Cualquiera de estas:
- **Compartida carpeta** entre Linux y VM (si está configurada)
- **Unidad USB** entre ambos hosts
- **Copiar el bundle vía SCP** desde tu terminal Linux:
  ```bash
  # Ejecutar en Linux, te pedirá la IP de la VM y credenciales del usuario Windows
  scp /mnt/Datos/Proyectos\ 2.0/PC/repaga-siemens/dist-pkg/valueflow-middleware-v1.0.zip \
      usuarioWindows@<IP_VM>:/Users/usuarioWindows/Desktop/
  ```

### 3. Extraer el bundle en la VM (~5s)

Click derecho en `valueflow-middleware-v1.0.zip` → "Extract All..." o:

```powershell
# PowerShell en la VM
Expand-Archive C:\Users\<usuario>\Desktop\valueflow-middleware-v1.0.zip -DestinationPath C:\temp\
# Crea: C:\temp\valueflow-middleware\
```

### 4. Compilar el instalador Inno Setup (~10s)

**Opción A — Click derecho en el .iss:**
1. Abre el explorador de archivos
2. Navega a `C:\temp\valueflow-middleware\installer\`
3. Click derecho en `installer.iss` → **"Compile"** (si tienes "Compile with Inno Setup" instalado)
   - Si no aparece la opción: doble click → "Sí" para abrir con Inno Setup

**Opción B — Línea de comandos (recomendado):**

```powershell
cd "C:\Program Files (x86)\Inno Setup 6"
.\ISCC.exe "C:\temp\valueflow-middleware\installer\installer.iss"
```

**Salida esperada:** `C:\temp\valueflow-middleware\installer\output\Valueflow-Setup-v1.0.exe` (10-15 MB)

### 5. Validar el .exe generado (~10s)

```powershell
# Verificar tamaño del archivo (debe ser ~10-15 MB)
Get-Item "C:\temp\valueflow-middleware\installer\output\Valueflow-Setup-v1.0.exe" | Select-Object Name, Length

# Verificar que abre el wizard (sin instalar)
& "C:\temp\valueflow-middleware\installer\output\Valueflow-Setup-v1.0.exe"
# Debe abrir wizard Next/Next/Install/Finish — cerrar ventana para abortar instalación
```

### 6. Probar instalación silenciosa completa (5 min)

Variables de entorno necesarias (defínelas en PowerShell antes de correr):

```powershell
$env:FIREBIRD_PASSWORD = "<firebird_password_del_cliente>"  # password real del usuario readonly (lo proporciona el cliente)
$env:UI_PASSWORD_PLAIN = "test1234"           # min 8 caracteres
$env:SIEMENS_API_KEY = "<api_key_real_qua_proporcionada_por_cliente>"  # reemplazar antes de instalar
$env:DATA_SOURCE = "qa"                       # o "production" cuando sea real
```

Instalación:

```powershell
cd "C:\temp\valueflow-middleware\installer"
.\install.bat
# O directo:
pwsh -File ".\install.ps1" -Silent -FirebirdDBPathOverride "C:\Program Files\Aspel\Aspel SAE 9.0\BD\SAE90EMPRE01.FDB"
```

Smoke tests esperados tras instalación:

```powershell
# 1. Verificar pm2 corriendo
pm2 status
# Esperado: siemens-middleware [online]

# 2. Abrir UI en navegador
Start-Process "http://localhost:4567"
# Esperado: dashboard con login

# 3. Login y test conexión Siemens
# Botón "Test conexión Siemens" debe devolver HTTP 4xx (validación)
# NO debe devolver 502 (eso confirmaría bug HTTP/2 sin fix)

# 4. Logs de la instalación
Get-Content "C:\apps\siemens-middleware\logs\$(Get-Date -Format 'yyyy-MM-dd')-middleware.log" -Tail 50
```

---

## 📋 Resultados esperados para considerar DONE

| Check | Esperado |
|-------|----------|
| `.exe` se compila sin errores | Output ~10-15 MB en `installer\output\` |
| Instalador corre sin pausas (silent) | pm2 status muestra `siemens-middleware` online |
| UI carga en `localhost:4567` | HTML de login visible |
| Test conexión Siemens → 4xx (no 502) | Bug HTTP/2 fix funciona |
| Ventas e2e → 5 facturas devueltas del JOIN | `sales.ts` con TRIM defensivo funciona |

Cuando todos los checks pasen, copiar logs a `analysis/PRUEBA_E2E_VENTAS_20260805.md` (Linux) o equivalente en Windows para cerrar `FACT-20260805-02`.

---

## ❌ Troubleshooting

### Inno Setup no compila porque detecta fechas erróneas

Abre `installer.iss` con Notepad, busca `MyAppVersion` y actualiza manualmente a `1.0.0`.

### `ISCC.exe` no se encuentra en `C:\Program Files (x86)\Inno Setup 6\`

Inno Setup puede haber instalado en otra ruta. Buscar:
```powershell
Get-ChildItem -Path 'C:\Program Files*' -Recurse -Filter ISCC.exe 2>$null | Select-Object FullName
```

### `pm2 startup` no instala el servicio de Windows

El instalador corre `pm2-startup install` para que el middleware se auto-inicie con Windows. Si falla:
- Abrir PowerShell como Administrador manualmente
- `npm install -g pm2-windows-startup`
- `pm2-startup install`
- `pm2 save`

### Error "node-gyp rebuild fails on Windows"

El paquete `node-firebird-driver-native` necesita compilar el binario nativo. Si no hay Visual Studio Build Tools instalado:

1. Instalar **Visual Studio Build Tools 2019+** desde https://visualstudio.microsoft.com/downloads/
2. Marcar workload "**Desktop development with C++**"
3. Reiniciar PowerShell
4. `cd C:\apps\siemens-middleware`
5. `npm install --production` (ahora compila el `.node` nativo)

---

## 📞 Soporte

Si encuentras algún error que no está en esta guía, Frank puede:
- Ver logs en `C:\apps\siemens-middleware\logs\`
- Reiniciar el servicio: `pm2 restart siemens-middleware`
- Verificar config: `notepad C:\apps\siemens-middleware\config.json`
