#!/bin/bash
# ============================================
# bump-version.sh - Incrementa version automaticamente
# Uso:
#   ./bump-version.sh [patch|minor|major]
# Default: patch (incrementa PATCH)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: No se encontro $VERSION_FILE"
    exit 1
fi

LEVEL="${1:-patch}"
DATE_TODAY=$(date +%Y-%m-%d)
GIT_HASH=$(git -C "$SCRIPT_DIR/.." rev-parse --short HEAD 2>/dev/null || echo "local-dev")

# Leer version actual
source "$VERSION_FILE"

echo "Version actual: v$MAJOR.$MINOR.$PATCH"

case "$LEVEL" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Uso: $0 [patch|minor|major]"
        exit 1
        ;;
esac

# Escribir nueva version
cat > "$VERSION_FILE" <<EOF
MAJOR=$MAJOR
MINOR=$MINOR
PATCH=$PATCH
BUILD_DATE=$DATE_TODAY
BUILD_HASH=$GIT_HASH
EOF

echo "Nueva version:   v$MAJOR.$MINOR.$PATCH (build $GIT_HASH @ $DATE_TODAY)"
echo ""
echo "Ahora ejecuta: bash installer/prepare-dist-pkg.sh && docker run ... ISCC.exe installer.iss"
