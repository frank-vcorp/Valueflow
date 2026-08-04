# SPEC-IMPL-20260804-01 — Distinguir errores de BD vs reales en Dashboard

**ID:** SPEC-IMPL-20260804-01
**Fecha:** 2026-08-04
**Estado:** Listo para delegación
**Agente ejecutor:** SOFIA
**Validación:** GEMINI

---

## 1. Problema

Actualmente, el Dashboard muestra "failed" en los jobs de Inventario y Ventas cuando el módulo nativo de Firebird no se puede cargar (típico en Linux porque `node-gyp` no compila). El error es del **entorno de desarrollo**, no del software.

**Confunde al usuario** porque parece que el software tiene un error real cuando en realidad es un problema de compilación nativa que no ocurrirá en producción (Windows con `fbclient.dll`).

## 2. Objetivo

Diferenciar **3 tipos de estado** en el Dashboard:

| Estado | Significado | Color sugerido | Cuándo se muestra |
|--------|-----------|----------------|---------------------|
| `success` | El job ejecutó sin errores | Verde | Job terminó con HTTP 201/200 |
| `failed` | Error real (BD no accesible en producción, error de red, etc.) | Rojo | Cualquier otro error |
| `db_unavailable` | El módulo nativo de Firebird no se pudo cargar (típico de dev) | Amarillo/naranja | Error contiene "bindings file", "Could not locate" |

## 3. Detección del tipo de error

El error de "BD no disponible" tiene estos patrones en el mensaje:
- `"Could not locate the bindings file"`
- `"node-firebird"` + `"build/addon.node"`
- `"compiled/"`
- `"Cannot find module"` cuando el módulo es `node-firebird-*`

**Implementación:** Crear una función helper `isFirebirdUnavailableError(error: unknown): boolean` en `src/db/firebird.ts` (o un nuevo archivo `src/utils/error-classifier.ts`) que detecte estos patrones.

## 4. Cambios a realizar

### 4.1 `src/db/firebird.ts` (o nuevo `src/utils/error-classifier.ts`)

Agregar función de clasificación:

```typescript
export function isFirebirdUnavailableError(error: unknown): boolean {
  if (!error) return false;
  const message = String(
    (error as { message?: string })?.message ?? 
    (error as { toString?: () => string })?.toString?.() ?? 
    error
  ).toLowerCase();
  
  const patterns = [
    'bindings file',
    'could not locate',
    'compiled/',
    'node-firebird',
    'addon.node',
    'cannot find module',
    'node-gyp'
  ];
  
  return patterns.some(p => message.includes(p));
}
```

### 4.2 `src/jobs/runInventory.ts` y `src/jobs/runSales.ts`

Modificar para que al capturar el error, lo categoricen:

```typescript
} catch (error) {
  const status: ExecutionStatus = isFirebirdUnavailableError(error) 
    ? 'db_unavailable' 
    : 'failed';
  // ... registrar con el status correcto
}
```

### 4.3 `src/scheduler/cron.ts`

Actualizar el tipo `JobExecution` para incluir el nuevo estado `db_unavailable`:

```typescript
type ExecutionStatus = 'running' | 'success' | 'failed' | 'db_unavailable' | 'skipped';
```

Y propagarlo correctamente al `execution.status`.

### 4.4 UI del Dashboard

En el template del dashboard (probablemente `src/ui/views/dashboard.html` o renderizado por una API):

- **success** → texto verde "correcto" o "OK" (como está actualmente)
- **failed** → texto rojo "con error" (como está actualmente)
- **db_unavailable** → texto amarillo/naranja "BD no accesible (entorno dev)" o "DB not accessible (dev environment)"
- **running** → texto gris (como está actualmente)
- **skipped** → texto gris (como está actualmente)

En la tabla de "Últimas ejecuciones":
- Agregar una columna visual (color o ícono) que distinga el tipo de error
- O usar texto descriptivo en la columna Estado

### 4.5 Logging

Cuando el error es `db_unavailable`, agregar al log un mensaje informativo:
- Level: `warn` (no `error`) porque es un problema de entorno, no del software
- Message: `"Base de datos no accesible (entorno de desarrollo). El middleware está listo para producción."`

## 5. Decisiones técnicas (NO cambiar)

| Aspecto | Decisión |
|---------|----------|
| **Detección** | Por mensaje del error (regex/string match) |
| **Color para db_unavailable** | Amarillo/naranja (`#f59e0b` de Tailwind) |
| **Texto sugerido** | "BD no accesible" (corto, claro) |
| **Log level** | `warn` (no `error`) |
| **Helper location** | En `src/db/firebird.ts` o nuevo `src/utils/error-classifier.ts` |

## 6. Validación esperada

```bash
cd /mnt/Datos/Proyectos 2.0/PC/repaga-siemens/middleware

# 1. Compilar
npm run build
# Sin errores

# 2. Iniciar
node dist/index.js &
sleep 3

# 3. Ejecutar inventario (debe fallar por BD no accesible en Linux)
curl -s -X POST -u admin:demo1234 http://127.0.0.1:4567/api/actions/inventory
# Debe mostrar mensaje relacionado

# 4. Ver log
cat /tmp/siemens-middleware-logs/2026-08-04-middleware.log | tail -5 | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        log = json.loads(line.strip())
        print(f'  [{log.get(\"level\", \"?\").upper():5s}] {log.get(\"message\", \"?\")[:80]}')
    except: pass
"

# 5. Verificar que el dashboard muestra el estado correcto
curl -s -u admin:demo1234 http://127.0.0.1:4567/ | grep -i "bd no accesible\|db_unavailable"
# Debe aparecer el mensaje en la UI
```

## 7. Lo que NO incluir

- ❌ NO cambiar la lógica de retry del job
- ❌ NO cambiar la estructura de los endpoints
- ❌ NO agregar nuevos endpoints o APIs
- ❌ NO cambiar el formato de logs
- ❌ NO traducir mensajes al inglés (mantener español)

## 8. Reporte esperado de SOFIA

```markdown
## Reporte SOFIA — Distinguir errores BD vs reales

### Estado: [COMPLETO / COMPLETO_CON_OBS / INCOMPLETO]

### Archivos modificados:
- [lista con paths y líneas modificadas]

### Validaciones:
- npm run build: [OK/FAIL]
- GET / dashboard muestra "BD no accesible" en lugar de "con error": [OK/FAIL]
- Log level es "warn" (no "error") para db_unavailable: [OK/FAIL]
- Job de inventory se ejecuta sin error de TypeScript: [OK/FAIL]

### Self-Review:
[respuestas]

### Observaciones:
[cualquier caveat]
```

---

*SPEC preparada por INTEGRA — ID: SPEC-IMPL-20260804-01*
*Pendiente: OK del usuario para delegar a SOFIA*