# SPEC-IMPL-20260804-03 — Paquete de distribución + Mejora de log

**ID:** SPEC-IMPL-20260804-03
**Fecha:** 2026-08-04
**Estado:** Listo para delegación
**Agente ejecutor:** SOFIA

---

## 1. Objetivo

Preparar el middleware para distribución en una VM Windows del cliente, con:

1. **Log mejorado** que distinga explícitamente entre datos reales (producción) y datos demo
2. **Paquete ZIP** listo para llevar a la VM Windows
3. **Instalador mejorado** que descargue Node.js, instale dependencias, configure PM2, etc.

---

## 2. Mejora 1 — Campo `data_source` en el log

### 2.1 Motivación

Cuando el middleware corre en Windows del cliente, los datos vienen de su BD real. Pero durante testing/demo, los datos son sintéticos. Es importante que el log muestre claramente de dónde vienen los datos.

### 2.2 Implementación

**`src/config/env.ts`** — Agregar nuevo campo:

```typescript
export const env = {
  // ... existing fields ...
  dataSource: process.env.DATA_SOURCE ?? 'demo', // 'production' | 'qa' | 'demo'
};
```

**`.env.example`** — Agregar:

```bash
# data_source: production (cliente Windows) | qa (testing) | demo (sintético)
DATA_SOURCE=demo
```

**`src/jobs/runInventory.ts` y `src/jobs/runSales.ts`** — Al loggear el job:

```typescript
logger.info('Iniciando job de inventario', {
  job: 'inventory',
  execution_id: ...,
  data_source: env.dataSource  // 'production' | 'qa' | 'demo'
});
```

### 2.3 Default

- **Default en código:** `'demo'` (para que sea seguro)
- **Default en `.env.example`:** `DATA_SOURCE=demo`
- **En instalación del cliente:** Se debe cambiar manualmente a `DATA_SOURCE=production` en el `.env`

### 2.4 Mensajes en log según `data_source`

| `data_source` | Prefijo en mensaje del log |
|---------------|---------------------------|
| `production` | Sin prefijo (es el caso normal) |
| `qa` | `[QA] ` prefijo en mensaje |
| `demo` | `[DEMO] ` prefijo en mensaje |

**Ejemplo:**
```
13:11:05-6  [INFO ]  [PRODUCTION] Iniciando job de inventario  data_source=production  job=inventory
13:11:05-6  [INFO ]  [DEMO] Iniciando job de inventario  data_source=demo  job=inventory
```

---

## 3. Mejora 2 — Paquete de distribución ZIP

### 3.1 Estructura del ZIP

Crear un directorio `dist-pkg/` con todo lo necesario:

```
dist-pkg/
├── valueflow-middleware/
│   ├── middleware/                  # Código fuente del middleware
│   │   ├── src/
│   │   ├── tests/
│   │   ├── docs/
│   │   ├── package.json
│   │   ├── package-lock.json
│   │   ├── tsconfig.json
│   │   ├── tsconfig.build.json
│   │   ├── .env.example
│   │   ├── config.json.example
│   │   └── ecosystem.config.js
│   ├── installer/                    # Scripts de instalación
│   │   ├── install.ps1
│   │   ├── install.bat
│   │   ├── installer.iss            # Para compilar .exe en Windows
│   │   └── build-installer.sh       # Script para compilar en Windows
│   ├── README.md
│   ├── INSTALL.md                    # Guía de instalación paso a paso
│   └── PROBAR-EN-VM.md              # Cómo probar en la VM Windows
```

### 3.2 Script: `installer/prepare-dist-pkg.sh`

Crear script bash que prepara el paquete de distribución:

```bash
#!/bin/bash
# Prepara el paquete de distribución para Windows
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_PKG="$PROJECT_ROOT/dist-pkg/valueflow-middleware"

echo "==> Preparando paquete de distribución..."

# Limpiar
rm -rf "$DIST_PKG"
mkdir -p "$DIST_PKG"

# Copiar middleware
cp -r "$PROJECT_ROOT/middleware" "$DIST_PKG/"

# Copiar installer
mkdir -p "$DIST_PKG/installer"
cp "$PROJECT_ROOT/installer/install.ps1" "$DIST_PKG/installer/"
cp "$PROJECT_ROOT/installer/install.bat" "$DIST_PKG/installer/"
cp "$PROJECT_ROOT/installer/installer.iss" "$DIST_PKG/installer/"
cp "$PROJECT_ROOT/installer/build-installer.sh" "$DIST_PKG/installer/"

# Copiar docs
cp "$PROJECT_ROOT/middleware/docs/SPEC-IMPL-20260804-01-distinguir-errores-bd-dashboard.md" "$DIST_PKG/middleware/docs/" 2>/dev/null || true
cp "$PROJECT_ROOT/middleware/docs/SPEC-IMPL-20260804-02-formato-log-hibrido.md" "$DIST_PKG/middleware/docs/" 2>/dev/null || true

# Crear README principal
cat > "$DIST_PKG/README.md" << 'EOF'
# Valueflow Middleware - Paquete de Distribución

## Contenido

- `middleware/` - Código fuente del middleware (Node.js + TypeScript)
- `installer/` - Scripts de instalación para Windows
- `INSTALL.md` - Guía paso a paso
- `PROBAR-EN-VM.md` - Cómo probar en VM Windows

## Instalación rápida (Windows)

1. Descomprimir esta carpeta en la PC destino
2. Abrir PowerShell como Administrador
3. Ejecutir: `cd installer; .\install.bat`
4. Seguir las instrucciones en pantalla

## Más información

Ver `INSTALL.md`.
EOF

# Crear INSTALL.md
cat > "$DIST_PKG/INSTALL.md" << 'EOF'
# Guía de Instalación - Valueflow Middleware

## Requisitos

- Windows 10/11 o Windows Server 2019+
- Aspel SAE 10 instalado
- Permisos de administrador

## Pasos

1. **Descomprimir** esta carpeta en la PC destino (ej. `C:\valueflow-middleware\`)

2. **Editar el archivo `.env`** que se generó en `middleware\.env` después de la instalación:
   - Cambiar `DATA_SOURCE=demo` a `DATA_SOURCE=production`
   - Verificar que la API Key de Siemens PRD esté configurada

3. **Ejecutar el instalador**:
   - Abrir PowerShell como Administrador
   - `cd middleware`
   - `npm install --production`
   - `npm run build`
   - `npm install -g pm2 pm2-windows-startup`
   - `pm2-startup install`
   - `pm2 start ecosystem.config.js`
   - `pm2 save`

4. **Verificar**:
   - Abrir navegador: `http://localhost:4567`
   - Iniciar sesión con las credenciales configuradas
   - Verificar que el log muestre `data_source=production`

## Más información

- Manual: `middleware/docs/MANUAL_USUARIO.html`
- Especificación técnica: `middleware/docs/SPEC-IMPL-20260804-*.md`
EOF

# Crear PROBAR-EN-VM.md
cat > "$DIST_PKG/PROBAR-EN-VM.md" << 'EOF'
# Cómo Probar en una VM Windows

## Antes de empezar

Necesitas:
- Una VM Windows 10/11 (VirtualBox, VMware, Hyper-V, etc.)
- Esta carpeta descomprimida en la VM
- Aspel SAE 10 instalado en la VM (puede ser versión demo)

## Pasos

1. **Configurar la VM**:
   - Mínimo 4 GB RAM, 2 vCPU, 20 GB disco
   - Red: NAT o Bridged
   - Compartir carpeta o copiar archivos

2. **Instalar Node.js** (si no está):
   - Descargar de https://nodejs.org/dist/v20.14.0/node-v20.14.0-x64.msi
   - Instalar con opciones por defecto

3. **Instalar Aspel SAE 10** (demo):
   - Ejecutar el instalador de SAE 10
   - Crear una empresa de prueba con productos de muestra
   - Anotar las credenciales de solo lectura para Firebird

4. **Compilar el módulo nativo de Firebird**:
   - Abrir Developer Command Prompt for VS 2019/2022 (como Admin)
   - `cd middleware`
   - `npm install` (compila node-firebird-native-api con MSVC)

5. **Ejecutar el instalador del middleware**:
   - `cd installer`
   - `.\install.bat`

6. **Configurar la conexión a SAE**:
   - Editar `middleware\.env`:
     ```
     FIREBIRD_PASSWORD=<password_solo_lectura>
     DATA_SOURCE=production
     ```

7. **Probar la UI**:
   - Abrir navegador: `http://localhost:4567`
   - Iniciar sesión
   - Ir a "Acciones" → "Test conexión SAE"
   - Si todo OK, ejecutar "Ejecutar Ventas ahora"
   - Verificar el log: `middleware\logs\2026-08-04-middleware.log`

## Compilar a .exe (opcional)

Si quieres tener un solo .exe instalable:

1. Instalar Inno Setup: https://jrsoftware.org/isdl.php
2. Abrir `installer\installer.iss` en Inno Setup
3. Compilar
4. Resultado en `installer\output\Valueflow-Setup-v1.0.exe`
EOF

# Crear el ZIP
cd "$PROJECT_ROOT/dist-pkg"
zip -r "valueflow-middleware-v1.0.zip" "valueflow-middleware/"

echo ""
echo "✓ Paquete de distribución creado en:"
echo "  $PROJECT_ROOT/dist-pkg/valueflow-middleware-v1.0.zip"
echo ""
echo "Tamaño: $(du -h $PROJECT_ROOT/dist-pkg/valueflow-middleware-v1.0.zip | cut -f1)"
```

### 3.3 Llamar este script desde `npm run package`

Modificar `middleware/package.json`:

```json
{
  "scripts": {
    "build": "tsc -p tsconfig.build.json && node scripts/copy-views.cjs",
    "build:docs": "tsc scripts/build-docs.ts && node scripts/build-docs.js",
    "package": "bash ../installer/prepare-dist-pkg.sh"
  }
}
```

---

## 4. Mejora 3 — Instalador mejorado

### 4.1 Cambios en `installer/install.ps1`

El instalador actual ya está bien. Solo agregar:

1. **Después de crear el `.env`**, agregar un mensaje claro sobre `DATA_SOURCE`:

```powershell
Write-Host ""
Write-Host "  IMPORTANTE: Para PRODUCCION, edite el archivo .env y cambie:" -ForegroundColor Yellow
Write-Host "    DATA_SOURCE=demo"
Write-Host "  Por:"
Write-Host "    DATA_SOURCE=production" -ForegroundColor Green
Write-Host ""
```

2. **Al iniciar el middleware por primera vez**, mostrar un mensaje según `DATA_SOURCE`:

```powershell
$dataSource = (Get-Content "$InstallDir\.env" | Select-String "DATA_SOURCE=").ToString().Split("=")[1].Trim()
if ($dataSource -eq "production") {
    Write-Host "  ✓ Modo PRODUCCION activado" -ForegroundColor Green
} elseif ($dataSource -eq "qa") {
    Write-Host "  ✓ Modo QA activado" -ForegroundColor Cyan
} else {
    Write-Host "  ! Modo DEMO activado (datos sinteticos)" -ForegroundColor Yellow
    Write-Host "    Para PRODUCCION, cambie DATA_SOURCE=production en .env" -ForegroundColor Yellow
}
```

### 4.2 Cambios en `installer/installer.iss`

Agregar al script de Inno Setup, una sección que descargue Node.js si no está:

```iss
[Code]
// Verificar si Node.js está instalado
function NodeInstalled: Boolean;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    Result := Reg.KeyExists('SOFTWARE\Node.js');
  finally
    Reg.Free;
  end;
end;

// Si Node.js no está, descargarlo
procedure DownloadNodeJs;
var
  ResultCode: Integer;
begin
  MsgBox('Node.js no detectado. Se descargará Node.js 20 LTS.', mbInformation, MB_OK);
  Exec('https://nodejs.org/dist/v20.14.0/node-v20.14.0-x64.msi', '', '', SW_SHOW, ewNoWait, ResultCode);
end;
```

Y en la sección `[Run]` agregar verificación:

```iss
[Run]
Filename: "{app}\middleware\installer\install.bat"; \
  Description: "Configurar e iniciar el servicio de Valueflow"; \
  Flags: nowait postinstall skipifsilent
```

---

## 5. Decisiones técnicas (NO cambiar)

| Aspecto | Decisión |
|---------|----------|
| `data_source` valores | `'production' \| 'qa' \| 'demo'` |
| Default `data_source` en código | `'demo'` (seguro) |
| Default `data_source` en `.env.example` | `DATA_SOURCE=demo` |
| Prefijo en log según `data_source` | `[PRODUCTION]`, `[QA]`, `[DEMO]` |
| Paquete ZIP | En `dist-pkg/valueflow-middleware-v1.0.zip` |
| Comando para crear ZIP | `npm run package` |

---

## 6. Validación esperada

```bash
cd /mnt/Datos/Proyectos 2.0/PC/repaga-siemens/middleware

# 1. Compilar
npm run build
# Sin errores

# 2. Verificar tipos
npx tsc --noEmit -p tsconfig.build.json
# Sin errores

# 3. Crear el paquete
npm run package
# Debe crear dist-pkg/valueflow-middleware-v1.0.zip

# 4. Verificar el ZIP
ls -la dist-pkg/valueflow-middleware-v1.0.zip

# 5. Verificar que el log muestra data_source
node dist/index.js &
sleep 3
curl -s -X POST -u admin:demo1234 http://127.0.0.1:4567/api/actions/inventory
sleep 2
cat /tmp/siemens-middleware-logs/2026-08-04-middleware.log | grep "data_source\|DEMO\|PRODUCTION"
# Debe mostrar [DEMO] y data_source=demo
```

---

## 7. Lo que NO incluir

- ❌ NO cambiar la lógica de envío de datos
- ❌ NO cambiar la estructura de la UI
- ❌ NO crear un .exe en Linux (no es posible por el módulo nativo)
- ❌ NO usar Electron o Chromium (overkill)

---

## 8. Reporte esperado de SOFIA

```markdown
## Reporte SOFIA — Paquete de distribución + Mejora de log

### Estado: [COMPLETO / COMPLETO_CON_OBS / INCOMPLETO]

### Archivos modificados/creados:
- [lista con paths y líneas]

### Validaciones ejecutadas:
- npm run build: [OK/FAIL]
- npx tsc --noEmit: [OK/FAIL]
- Log muestra "data_source=demo" y "[DEMO]": [OK/FAIL]
- npm run package: [OK/FAIL]
- ZIP creado en dist-pkg/: [OK/FAIL]
- Tamaño del ZIP: [X MB]

### Self-Review:
[respuestas]

### Observaciones:
[cualquier caveat]
```

---

*SPEC preparada por INTEGRA — ID: SPEC-IMPL-20260804-03*
*Pendiente: delegación a SOFIA*