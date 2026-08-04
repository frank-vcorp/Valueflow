import winston from 'winston';

const MESSAGE = Symbol.for('message');

const COLORS: Record<string, string> = {
  info: '\x1b[32m',
  warn: '\x1b[33m',
  error: '\x1b[31m',
  debug: '\x1b[90m'
};
const RESET = '\x1b[0m';

const MESSAGE_MAX = 200;
const ERROR_MAX = 200;

const truncate = (str: string, max: number): string => {
  if (!str || str.length <= max) return str;
  return str.substring(0, max) + `... [+${str.length - max} chars]`;
};

interface ErrorLike {
  name?: string;
  message?: string;
  [key: string]: unknown;
}

const truncateError = (err: unknown, max: number): string => {
  if (!err) return '';
  if (typeof err === 'string') return truncate(err, max);
  const obj = err as ErrorLike;
  const name = typeof obj.name === 'string' ? obj.name : 'Error';
  let message = typeof obj.message === 'string' ? obj.message : String(err);
  message = message.replace(/\n\s*→\s+\/.*$/m, '');
  const firstLine = message.split('\n')[0] ?? message;
  return truncate(`${name}: ${firstLine}`, max);
};

const RESERVED_KEYS = new Set(['level', 'message', 'timestamp', 'service']);
// `error` se renderiza aparte (segunda línea truncada); excluirlo del meta inline.
const ERROR_KEYS = new Set(['error', 'stack']);

const formatMeta = (info: Record<string, unknown>): string => {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(info)) {
    if (RESERVED_KEYS.has(key)) continue;
    if (ERROR_KEYS.has(key)) continue;
    if (value === undefined || value === null) continue;
    const strValue = typeof value === 'string' ? `"${value}"` : String(value);
    parts.push(`${key}=${strValue}`);
  }
  return parts.length > 0 ? '  ' + parts.join('  ') : '';
};

/**
 * Format híbrido para Winston.
 * - Una línea por evento: HH:MM:SS±TZ  [LEVEL ]  mensaje  meta=valor
 * - Errores en segunda línea, truncados a 200 chars (solo primera línea).
 * - Colores ANSI solo si process.stdout.isTTY (terminal interactiva).
 * - Compatible con archivos, pipes y Bloc de Notas (sin colores, sin escapes).
 */
export const hybridFormat = winston.format((info) => {
  const level = typeof info.level === 'string' ? info.level : 'info';
  const message = typeof info.message === 'string' ? info.message : '';
  const rawTimestamp = typeof info.timestamp === 'string' ? info.timestamp : new Date().toISOString();
  const timeOnly = rawTimestamp.includes('T') ? (rawTimestamp.split('T')[1] ?? rawTimestamp) : rawTimestamp;

  // Prefijo según data_source (solo si el campo existe en el meta del log entry).
  // 'production' → sin prefijo (caso normal); 'qa' → [QA]; 'demo' → [DEMO].
  const rawDataSource = info['data_source'];
  let dataSourcePrefix = '';
  if (typeof rawDataSource === 'string') {
    const ds = rawDataSource.toLowerCase();
    if (ds === 'qa') dataSourcePrefix = '[QA] ';
    else if (ds === 'demo') dataSourcePrefix = '[DEMO] ';
  }

  const truncatedMsg = truncate(dataSourcePrefix + message, MESSAGE_MAX);

  const errorField = info['error'];
  const truncatedError = errorField ? truncateError(errorField, ERROR_MAX) : '';

  const meta = formatMeta(info as Record<string, unknown>);

  const useColor = process.stdout.isTTY === true;
  const color = useColor ? (COLORS[level] ?? '') : '';
  const reset = useColor ? RESET : '';

  let line = `${timeOnly}  [${color}${level.toUpperCase().padEnd(5)}${reset}]  ${truncatedMsg}${meta}`;

  if (truncatedError && !message.includes(truncatedError)) {
    line += `\n                  ${truncatedError}`;
  }

  info[MESSAGE] = line;
  return info;
});