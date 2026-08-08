#!/bin/bash
# ============================================
# Prepara el paquete de distribución para Windows
# Lee la version de installer/VERSION y crea el bundle con esa version.
#
# Salida:
#   - dist-pkg/valueflow-middleware-v<version>.zip (bundle portable)
#   - dist-pkg/Valueflow-Setup-v<version>.exe (instalable, si se compila despues)
#
# Flujo tipico:
#   1. cd /mnt/Datos/Proyectos\ 2.0/PC/repaga-siemens
#   2. bash installer/bump-version.sh patch       # o minor/major
#   3. bash installer/prepare-dist-pkg.sh          # genera bundle con nueva version
#   4. docker run ... ISCC.exe installer/installer.iss   # compila instalable
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"

# Cargar version
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: No existe $VERSION_FILE"
    echo "Crea el archivo con:"
    echo "  echo 'MAJOR=1' > $VERSION_FILE"
    echo "  echo 'MINOR=0' >> $VERSION_FILE"
    echo "  echo 'PATCH=0' >> $VERSION_FILE"
    exit 1
fi

source "$VERSION_FILE"
VERSION_STRING="v$MAJOR.$MINOR.$PATCH"
echo "==> Preparando paquete de distribución $VERSION_STRING (build $BUILD_HASH @ $BUILD_DATE)"

# ============================================
# 0. Pre-build: compilar middleware antes de empaquetar
#    (BUG FIX B5: antes el bundle se generaba sin dist/, instalador en VM
#     quedaba con login roto porque no habia dist/index.js).
# ============================================
echo "==> Pre-build: compilando middleware (npm run build)"
cd "$PROJECT_ROOT/middleware"

if [[ ! -f "package.json" ]]; then
    echo "ERROR: package.json no existe en $PROJECT_ROOT/middleware"
    exit 1
fi

if [[ ! -d "node_modules" ]]; then
    echo "==> node_modules ausente, instalando (sin scripts que intenten compilar nativos en CI)..."
    npm install --ignore-scripts --no-audit --no-fund || {
        echo "ERROR: npm install fallo en pre-build"
        exit 1
    }
fi

npm run build || {
    echo "ERROR: npm run build fallo en pre-build. Revisar errores de TypeScript."
    exit 1
}

if [[ ! -f "dist/index.js" ]]; then
    echo "ERROR: dist/index.js no se genero tras npm run build. Abortando."
    exit 1
fi
echo "==> Pre-build OK: dist/index.js presente"

cd "$SCRIPT_DIR"

# Directorios
DIST_PKG_BASE="$PROJECT_ROOT/dist-pkg"
DIST_PKG="$DIST_PKG_BASE/valueflow-middleware-$VERSION_STRING"

# Limpiar version anterior si existe
rm -rf "$DIST_PKG"
mkdir -p "$DIST_PKG"

# ============================================
# 1. Actualizar installer.iss con la version actual
# ============================================
echo "==> Actualizando installer.iss con version $VERSION_STRING"
ISS_FILE="$SCRIPT_DIR/installer.iss"

# Backup del .iss si tiene un #define diferente
if [[ -f "$ISS_FILE" ]]; then
    cp "$ISS_FILE" "$ISS_FILE.bak"
fi

# Reemplazar las 3 lineas de #define de version
python3 - <<EOF
import re
with open("$ISS_FILE", "r") as f:
    content = f.read()

# Reemplazar #define MyAppVersion "X.Y"
content = re.sub(
    r'#define MyAppVersion "[^"]+"',
    f'#define MyAppVersion "$MAJOR.$MINOR.$PATCH"',
    content
)

# Reemplazar OutputBaseFilename=Valueflow-Setup-vX.Y
content = re.sub(
    r'OutputBaseFilename=Valueflow-Setup-v[^#\s]+',
    f'OutputBaseFilename=Valueflow-Setup-$VERSION_STRING',
    content
)

# Reemplazar AppVerName
content = re.sub(
    r'AppVerName=\{#MyAppName\} v\{#MyAppVersion\}',
    f'AppVerName={{#MyAppName}} v$VERSION_STRING (build $BUILD_DATE)',
    content
)

# Agregar VERSION_INFO_COMMENTS con hash del build
content = re.sub(
    r'VersionInfoDescription=Valueflow Middleware Installer',
    f'VersionInfoDescription=Valueflow Middleware Installer',
    content
)

with open("$ISS_FILE", "w") as f:
    f.write(content)
print("OK")
EOF

# ============================================
# 2. Actualizar prepare-dist-pkg.sh mismo (para siguientes invocaciones)
# ============================================

# ============================================
# 3. Copiar archivos
# ============================================

# Copiar middleware (sin node_modules, logs, coverage, .env real). dist/ SI va incluido
# porque ahora pre-compilamos antes de empaquetar (BUG FIX B5). El node_modules
# del working tree NO se copia (puede tener binarios .node Linux no portables);
# se genera uno fresco portable en staging mas abajo (IMPL-20260807-03, F1 fix).
mkdir -p "$DIST_PKG/middleware"
rsync -a --exclude='node_modules' --exclude='logs' \
          --exclude='coverage' --exclude='.env' --exclude='*.log' \
          --exclude='.git' \
          "$PROJECT_ROOT/middleware/" "$DIST_PKG/middleware/"

# Sanity check: dist/index.js debe estar presente en el bundle
if [[ ! -f "$DIST_PKG/middleware/dist/index.js" ]]; then
    echo "ERROR: dist/index.js no se copio al bundle. Abortando."
    exit 1
fi
echo "==> Bundle contiene dist/index.js (pre-compilado)"

# ============================================
# IMPL-20260807-03: Pre-instalar node_modules en el staging (bundle self-contained)
# El bundle v2.0.11 deja de depender de internet/proxy/firewall en la VM cliente:
# node_modules va pre-instalado y portable (todo JS puro, sin .node nativos) para
# que install.ps1 pueda hacer skip del npm install en destino.
# ============================================
echo "==> Pre-instalando node_modules portable en staging del bundle..."
cd "$DIST_PKG/middleware"
npm install --omit=dev --ignore-scripts --no-audit --no-fund || {
    echo "ERROR: npm install fallo en staging del bundle"
    exit 1
}

# Verificar que node_modules se creo
if [[ ! -d "node_modules" ]]; then
    echo "ERROR: node_modules no se creo en staging"
    exit 1
fi
[[ -d "node_modules/.bin" ]] || mkdir -p "node_modules/.bin"

# Verificar tamano razonable (< 100 MB; si pesa mas, posible binario nativo no portable)
SIZE=$(du -sm "$DIST_PKG/middleware/node_modules" | cut -f1)
if [[ "$SIZE" -ge 100 ]]; then
    echo "ERROR: node_modules pesa ${SIZE}MB >= 100MB — posible binario nativo no portable"
    exit 1
fi

# Verificar que NO hay archivos .node (binarios nativos) en el bundle
NATIVE_NODES=$(find "$DIST_PKG/middleware/node_modules" -name "*.node" 2>/dev/null)
if [[ -n "$NATIVE_NODES" ]]; then
    echo "ERROR: encontrado .node nativo en node_modules del bundle — NO portable a Windows"
    echo "$NATIVE_NODES"
    exit 1
fi
echo "==> node_modules portable OK (${SIZE}MB, sin .node nativos)"
cd "$SCRIPT_DIR"

# Copiar installer
mkdir -p "$DIST_PKG/installer"
cp "$SCRIPT_DIR/install.ps1" "$DIST_PKG/installer/"
cp "$SCRIPT_DIR/install.bat" "$DIST_PKG/installer/"
cp "$SCRIPT_DIR/uninstall.bat" "$DIST_PKG/installer/"
cp "$SCRIPT_DIR/installer.iss" "$DIST_PKG/installer/"
[ -f "$SCRIPT_DIR/build-installer.sh" ] && cp "$SCRIPT_DIR/build-installer.sh" "$DIST_PKG/installer/"

# Copiar VERSION para que el bundle sea auto-contenido
cp "$VERSION_FILE" "$DIST_PKG/installer/"

# Copiar assets (logos, etc.) — EXCLUIR installers/ del staging del bundle.
# Los binarios del sistema en assets/installers/ (node MSI, vc_redist, node
# x86 zip) ya viajan directamente al .exe via installer.iss [Files] lineas
# 65-67, que los deploya en {app}\installer\assets\installers\. Si los
# embebieramos tambien dentro del bundle.zip (asset del .exe via linea 54),
# quedarian duplicados dentro del mismo .exe y lo inflariamos ~62 MB sin
# beneficio. El bundle.zip solo necesita assets no-installer (icono .ico)
# ademas de middleware/ para su proposito de fallback en install.ps1 PASO 7.
if [ -d "$SCRIPT_DIR/assets" ]; then
    mkdir -p "$DIST_PKG/installer/assets"
    for item in "$SCRIPT_DIR/assets/"*; do
        case "$(basename "$item")" in
            installers) ;;  # skip: ya viaja al .exe via installer.iss lineas 65-67
            *) cp -r "$item" "$DIST_PKG/installer/assets/" ;;
        esac
    done
fi

# ============================================
# 4. Crear README principal
# ============================================
cat > "$DIST_PKG/README.md" << EOF
# Valueflow Middleware - Paquete de Distribución $VERSION_STRING

**Build:** $BUILD_HASH @ $BUILD_DATE
**Cliente:** REPRESENTACIONES AGA 2 (Repaga)

## Contenido

- `middleware/` - Código fuente del middleware (Node.js + TypeScript) + `node_modules/` pre-instalado portable (sin .node nativos)
- `installer/` - Scripts de instalación para Windows
- `INSTALL.md` - Guía paso a paso
- `PROBAR-EN-VM.md` - Cómo probar en VM Windows

## Instalación rápida (Windows)

1. Descomprimir esta carpeta en la PC destino
2. Abrir PowerShell como Administrador
3. Ejecutar: `cd installer; .\install.bat`
4. Seguir las instrucciones en pantalla

## Requisitos de Firebird

El middleware usa `node-firebird` (driver JS puro, sin bindings nativos). Por lo tanto:

- **NO requiere** `fbclient.dll` cliente en la VM Windows
- **SÍ requiere** que el servidor **Firebird** esté corriendo en `localhost:3050` con la base SAE accesible
  (parte de la instalación de Aspel SAE 10). El instalador detecta la ruta del .FDB en el wizard.

## Versión

$VERSION_STRING (build $BUILD_HASH)
Generado: $BUILD_DATE

## Más información

Ver \`INSTALL.md\`.
EOF

# Crear INSTALL.md con la versión
cat > "$DIST_PKG/INSTALL.md" << EOF
# Guía de Instalación - Valueflow Middleware $VERSION_STRING

## Requisitos

- Windows 10/11 o Windows Server 2019+
- Aspel SAE 10 instalado
- Permisos de administrador

## Pasos

1. **Doble click** en \`installer/Valueflow-Setup-$VERSION_STRING.exe\` (recomendado)
   O **Descomprimir** esta carpeta y ejecutar \`installer/install.bat\`

2. **Wizard del instalador**:
   - Selecciona ruta del archivo .FDB de Aspel SAE (usa Examinar...)
   - Click Install
   - Espera 2-3 minutos (extrae Node.js portable, instala deps, configura)

3. **Login UI**: user=\`Admin\`, pass=\`Admin123\` (cambiable desde UI)

4. **Configurar API Key Siemens** desde UI Configuración (default: sandbox QUA)

5. **Verificar**:
   - Abrir navegador: \`http://localhost:4567\`
   - Dashboard muestra ventas/inventario con datos reales
EOF

# ============================================
# 5. Crear el ZIP
# ============================================
cd "$DIST_PKG_BASE"
ZIP_PATH="$DIST_PKG_BASE/valueflow-middleware-$VERSION_STRING.zip"
if command -v zip >/dev/null 2>&1; then
  # Limpiar ZIPs viejos del mismo directorio (solo si son de versiones anteriores)
  rm -f "$DIST_PKG_BASE"/valueflow-middleware-v*.zip
  zip -r "valueflow-middleware-$VERSION_STRING.zip" "valueflow-middleware-$VERSION_STRING/" -x "*.DS_Store"
else
  echo "ERROR: 'zip' no está instalado. Instálalo: sudo apt install zip"
  exit 1
fi

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo ""
echo "✓ Bundle creado:"
echo "  $ZIP_PATH"
echo ""
echo "Tamaño: $ZIP_SIZE"
echo ""
echo "Próximo paso: compilar el instalable .exe con Inno Setup"
echo "  docker run --rm -v \$(pwd):/work -w /work/installer amake/innosetup:latest \\"
echo "    /opt/innosetup/ISCC.exe installer/installer.iss"
echo ""
echo "El .exe quedara en: installer/build_output/Valueflow-Setup-$VERSION_STRING.exe"
