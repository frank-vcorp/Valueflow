#!/bin/bash
# ============================================
# Script para compilar el instalador .exe desde Linux
# Usa Wine + Inno Setup
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  Compilador de Valueflow Installer (.exe)             ║"
echo "║  Vía Wine + Inno Setup en Linux                        ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Verificar que wine está instalado
if ! command -v wine &> /dev/null; then
    echo "✗ Wine no está instalado."
    echo ""
    echo "Para instalar Wine en Ubuntu/Debian:"
    echo "  sudo dpkg --add-architecture i386"
    echo "  sudo apt update"
    echo "  sudo apt install wine64 wine32"
    echo ""
    echo "En Fedora:"
    echo "  sudo dnf install wine"
    echo ""
    echo "En Arch:"
    echo "  sudo pacman -S wine"
    exit 1
fi

echo "✓ Wine detectado: $(wine --version)"
echo ""

# Verificar estructura
if [ ! -d "middleware" ]; then
    echo "✗ No se encontró el directorio middleware/"
    exit 1
fi

if [ ! -d "assets" ]; then
    echo "✗ No se encontró el directorio assets/"
    exit 1
fi

# Verificar que Inno Setup está disponible vía Wine
ISCC_PATH=$(find ~/.wine/drive_c/ -name "ISCC.exe" 2>/dev/null | head -1)
if [ -z "$ISCC_PATH" ]; then
    echo "⚠ Inno Setup no encontrado en Wine. Descargando..."

    mkdir -p /tmp/innosetup
    cd /tmp/innosetup
    wget -q "https://jrsoftware.org/download.php/is.exe" -O innosetup.exe

    echo "Instalando Inno Setup silenciosamente..."
    wine innosetup.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /DIR="C:\\InnoSetup" 2>&1 | tail -5

    cd "$SCRIPT_DIR/.."
    ISCC_PATH=$(find ~/.wine/drive_c/ -name "ISCC.exe" 2>/dev/null | head -1)
fi

if [ -z "$ISCC_PATH" ]; then
    echo "✗ No se pudo instalar/obtener Inno Setup"
    exit 1
fi

echo "✓ Inno Setup encontrado: $ISCC_PATH"
echo ""

# Crear directorio temporal con estructura requerida por Inno Setup
TMPDIR=$(mktemp -d)
echo "→ Preparando estructura temporal en $TMPDIR"
cp -r middleware "$TMPDIR/middleware"
cp -r assets "$TMPDIR/assets"
cp -r installer "$TMPDIR/installer"

cd "$TMPDIR/installer"

# Compilar con Wine
echo ""
echo "═══════════════════════════════════════════════════"
echo "  Compilando installer.iss con Wine + Inno Setup..."
echo "═══════════════════════════════════════════════════"
echo ""

wine "$ISCC_PATH" installer.iss 2>&1 | tail -20

# Verificar output
OUTPUT_EXE="$TMPDIR/installer/output/Valueflow-Setup-1.0.exe"
if [ -f "$OUTPUT_EXE" ]; then
    FINAL_PATH="$SCRIPT_DIR/installer/output/Valueflow-Setup-1.0.exe"
    mkdir -p "$SCRIPT_DIR/installer/output"
    cp "$OUTPUT_EXE" "$FINAL_PATH"

    SIZE=$(du -h "$FINAL_PATH" | cut -f1)
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  ✓ COMPILACIÓN EXITOSA"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "  Instalador generado:"
    echo "    $FINAL_PATH"
    echo "  Tamaño: $SIZE"
    echo ""
    echo "  Listo para enviar al cliente por correo o USB."
else
    echo "✗ La compilación falló. No se encontró el .exe generado."
    exit 1
fi

# Limpiar
rm -rf "$TMPDIR"