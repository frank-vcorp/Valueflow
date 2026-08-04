# SPEC-IMPL-20260804-02 — Formato de log híbrido con banners y colores

**ID:** SPEC-IMPL-20260804-02
**Fecha:** 2026-08-04
**Estado:** Listo para delegación
**Agente ejecutor:** SOFIA

---

## 1. Problema

El log actual (JSON compacto, una línea por evento) es muy difícil de leer cuando hay errores largos. El caso típico:

```json
{"attempt":1,"error":{"message":"Could not locate the bindings file. Tried:\n → /mnt/.../build/addon.node\n → /mnt/.../build/Debug/addon.node\n → /mnt/.../build/Release/addon.node\n ... 9 paths más ..."},"level":"warn","message":"Error en query Firebird; reintentando","service":"siemens-middleware","timestamp":"2026-08-04T12:42:00-6"}
```

Una sola línea de ~2000 caracteres que satura la pantalla.

## 2. Objetivo

Cambiar el formato del log a uno **legible y escaneable**, manteniendo la parseabilidad JSON. Formato:

### 2.1 Cabecera por día (al inicio del archivo)

```
═══════════════════════════════════════════════════════════════════
  📅 2026-08-04  Valorflow Middleware
═══════════════════════════════════════════════════════════════════
```

### 2.2 Una línea por evento

```
12:34:07-06:00  [INFO ]  UI iniciada
12:34:07-06:00  [INFO ]  Schedulers iniciados  inventory="0 2 * * *"  sales="0 3 * * *"
12:34:20-06:00  [INFO ]  Prueba de conexión Siemens ejecutada  status=201
12:42:00-06:00  [WARN ]  Error en query Firebird  attempt=1
12:42:00-06:00  [WARN ]  Error en query Firebird  attempt=2
12:42:00-06:00  [WARN ]  Error en query Firebird  attempt=3
12:42:00-06:00  [WARN ]  BD no accesible (entorno de desarrollo)
                  El middleware está listo para producción.
```

### 2.3 Truncado automático

- Mensaje > 200 caracteres: truncar a 200 + `... [+N chars]`
- Errores con arrays largos: solo el primer elemento + `... (N total)`
- Ejemplo: `error="Could not locate bindings file. Tried: /mnt/.../build/addon.node ... (13 paths total)"`

### 2.4 Colores ANSI (solo si terminal los soporta)

Si `process.stdout.isTTY` o el archivo NO se redirige a un pipe:

| Nivel | Color ANSI | Hex |
|-------|-----------|-----|
| `info` | Verde | `\x1b[32m` |
| `warn` | Amarillo | `\x1b[33m` |
| `error` | Rojo | `\x1b[31m` |
| `debug` | Gris | `\x1b[90m` |

**Si NO hay TTY (archivo, pipe, Bloc de Notas):** NO emitir códigos ANSI, solo texto plano.

**Reset:** `\x1b[0m` después de cada nivel.

## 3. Implementación

### 3.1 Nuevo archivo: `src/logger/format.ts`

Crear un format function para Winston que implemente el formato híbrido:

```typescript
import winston from 'winston';

const COLORS = {
  info: '\x1b[32m',   // green
  warn: '\x1b[33m',   // yellow
  error: '\x1b[31m',  // red
  debug: '\x1b[90m'  // gray
};
const RESET = '\x1b[0m';

const truncate = (str: string, max = 200): string => {
  if (!str || str.length <= max) return str;
  return str.substring(0, max) + `... [+${str.length - max} chars]`;
};

const truncateError = (err: unknown, max = 200): string => {
  if (!err) return '';
  if (typeof err === 'string') return truncate(err, max);
  const obj = err as { message?: string; name?: string; [k: string]: unknown };
  let message = obj.message ?? String(err);
  // Si el mensaje tiene muchos \n (paths intentados), truncar
  message = message.replace(/\n\s*→\s+\/.*$/m, ''); // remover líneas de paths
  message = message.split('\n')[0] ?? message; // solo primera línea
  return truncate(`${obj.name ?? 'Error'}: ${message}`, max);
};

const formatMeta = (info: Record<string, unknown>): string => {
  const meta: string[] = [];
  for (const [key, value] of Object.entries(info)) {
    if (['level', 'message', 'timestamp', 'service'].includes(key)) continue;
    if (value === undefined || value === null) continue;
    const strValue = typeof value === 'string' ? `"${value}"` : String(value);
    meta.push(`${key}=${strValue}`);
  }
  return meta.length > 0 ? '  ' + meta.join('  ') : '';
};

export const hybridFormat = winston.format((info) => {
  const level = (info.level as string) ?? 'info';
  const message = (info.message as string) ?? '';
  const timestamp = (info.timestamp as string) ?? new Date().toISOString();
  // Quitar la fecha del timestamp, dejar solo hora
  const timeOnly = timestamp.includes('T') ? timestamp.split('T')[1] ?? timestamp : timestamp;

  // Truncar mensaje
  const truncatedMsg = truncate(message, 200);

  // Truncar error si existe
  const error = info['error'];
  const truncatedError = error ? truncateError(error, 200) : '';

  // Formatear metadatos
  const meta = formatMeta(info);

  // Color ANSI si la terminal lo soporta
  const useColor = process.stdout.isTTY === true;
  const color = useColor ? (COLORS[level as keyof typeof COLORS] ?? '') : '';
  const reset = useColor ? RESET : '';

  // Construir la línea
  let line = `${timeOnly}  [${color}${level.toUpperCase().padEnd(5)}${reset}]  ${truncatedMsg}${meta}`;

  if (truncatedError && !message.includes(truncatedError)) {
    line += `\n                  ${truncatedError}`;
  }

  info.message = line;
  return info;
});
```

### 3.2 Cabecera por día

Crear un format adicional que escribe la cabecera al inicio del archivo:

```typescript
export const dailyHeaderFormat = winston.format((info) => {
  // Solo se ejecuta una vez por día (al primer log del día)
  // Usar un timestamp en formato YYYY-MM-DD para detectar el día
  const today = new Date().toISOString().split('T')[0];
  // La cabecera se inserta en el stream directamente al crear el archivo
  return info;
});
```

Mejor approach: usar `winston-daily-rotate-file` con una opción de "header" o crear el archivo con la cabecera manualmente.

**Approach simple:** usar `DailyFileStream` (que ya existe) y escribir la cabecera cuando se abre un nuevo archivo:

```typescript
class DailyFileStream extends Writable {
  // ... existing code ...
  private openStream(): void {
    if (this.currentStream) {
      this.currentStream.end();
    }
    this.currentStream = fs.createWriteStream(this.getFilePath(), { flags: 'a' });
    // Escribir cabecera al inicio
    const today = new Date().toISOString().split('T')[0];
    const header = `═══════════════════════════════════════════════════════════════════\n  📅 ${today}  Valorflow Middleware\n═══════════════════════════════════════════════════════════════════\n\n`;
    this.currentStream.write(header);
  }
}
```

### 3.3 Integración en `winston.ts`

Modificar el logger para usar el nuevo format:

```typescript
import { hybridFormat, dailyHeaderFormat } from './format';

// ... existing code ...

const logger = winston.createLogger({
  level: env.logLevel,
  format: winston.format.combine(
    redactFormat(),  // mantiene la redacción de secrets
    hybridFormat(),  // nuevo formato híbrido
  ),
  defaultMeta: { service: 'siemens-middleware' },
  transports: [transport, new winston.transports.Console()]
});
```

## 4. Decisiones técnicas (NO cambiar)

| Aspecto | Decisión |
|---------|----------|
| **Truncado mensaje** | 200 caracteres |
| **Truncado error** | 200 caracteres |
| **Colores** | Solo si TTY (process.stdout.isTTY) |
| **Cabecera** | Al inicio de cada archivo de día |
| **Compatibilidad** | Funciona en VSCode, terminal, Bloc de Notas |
| **Redact** | Mantener la redacción de secrets existente |

## 5. Validación esperada

```bash
cd /mnt/Datos/Proyectos 2.0/PC/repaga-siemens/middleware

# 1. Compilar
npm run build
# Sin errores TypeScript

# 2. Limpiar y reiniciar
pkill -9 -f "node dist/index" 2>&1
sleep 2
rm -rf /tmp/siemens-middleware-logs/
mkdir -p /tmp/siemens-middleware-logs/
node dist/index.js &
sleep 3

# 3. Generar eventos
curl -s -X POST -u admin:demo1234 http://127.0.0.1:4567/api/actions/test-siemens
curl -s -X POST -u admin:demo1234 http://127.0.0.1:4567/api/actions/inventory
sleep 2

# 4. Ver el log (debe estar formateado)
cat /tmp/siemens-middleware-logs/2026-08-04-middleware.log
# Debe verse:
# - Cabecera con "════════" y fecha
# - Una línea por evento
# - Errores truncados
```

## 6. Lo que NO incluir

- ❌ NO cambiar la lógica de redacción de secrets
- ❌ NO cambiar la rotación de archivos (sigue por día)
- ❌ NO cambiar la estructura de los eventos (siguen siendo objetos con level, message, timestamp, etc.)
- ❌ NO agregar formato de log separado para stdout vs archivo
- ❌ NO cambiar el log level (info, warn, error, debug)

## 7. Reporte esperado de SOFIA

```markdown
## Reporte SOFIA — Formato de log híbrido

### Estado: [COMPLETO / COMPLETO_CON_OBS / INCOMPLETO]

### Archivos modificados:
- [lista]

### Validaciones:
- npm run build: [OK/FAIL]
- npx tsc --noEmit: [OK/FAIL]
- Log tiene cabecera con fecha: [OK/FAIL]
- Una línea por evento: [OK/FAIL]
- Errores truncados: [OK/FAIL]
- Tests existentes pasan: [OK/FAIL]

### Self-Review:
[respuestas]

### Observaciones:
[cualquier caveat]
```

---

*SPEC preparada por INTEGRA — ID: SPEC-IMPL-20260804-02*
*Pendiente: delegación a SOFIA*