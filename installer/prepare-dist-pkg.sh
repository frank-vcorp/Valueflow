#!/bin/bash
# ============================================
# Prepara el paquete de distribución para Windows
# Crea dist-pkg/valueflow-middleware-v1.0.zip con todo lo necesario
# para llevar el middleware a una VM Windows del cliente.
#
# Salida: <PROJECT_ROOT>/dist-pkg/valueflow-middleware-v1.0.zip
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_PKG="$PROJECT_ROOT/dist-pkg/valueflow-middleware"

echo "==> Preparando paquete de distribución..."

# Limpiar
rm -rf "$DIST_PKG"
mkdir -p "$DIST_PKG"

# Copiar middleware (sin node_modules, dist, logs, coverage, .env real)
mkdir -p "$DIST_PKG/middleware"
rsync -a --exclude='node_modules' --exclude='dist' --exclude='logs' \
          --exclude='coverage' --exclude='.env' --exclude='*.log' \
          --exclude='.git' \
          "$PROJECT_ROOT/middleware/" "$DIST_PKG/middleware/"

# Copiar installer
mkdir -p "$DIST_PKG/installer"
cp "$SCRIPT_DIR/install.ps1" "$DIST_PKG/installer/"
cp "$SCRIPT_DIR/install.bat" "$DIST_PKG/installer/"
cp "$SCRIPT_DIR/installer.iss" "$DIST_PKG/installer/"
[ -f "$SCRIPT_DIR/build-installer.sh" ] && cp "$SCRIPT_DIR/build-installer.sh" "$DIST_PKG/installer/"

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
3. Ejecutar: `cd installer; .\install.bat`
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

# Crear el ZIP (mantener symlinks NO; entries de zip estables en Windows)
cd "$PROJECT_ROOT/dist-pkg"
if command -v zip >/dev/null 2>&1; then
  zip -r "valueflow-middleware-v1.0.zip" "valueflow-middleware/" -x "*.DS_Store"
else
  echo "✗ 'zip' no está instalado. Instálalo: sudo apt install zip"
  exit 1
fi

ZIP_PATH="$PROJECT_ROOT/dist-pkg/valueflow-middleware-v1.0.zip"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo ""
echo "✓ Paquete de distribución creado en:"
echo "  $ZIP_PATH"
echo ""
echo "Tamaño: $ZIP_SIZE"