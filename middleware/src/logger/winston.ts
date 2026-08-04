import fs from 'node:fs';
import path from 'node:path';
import { Writable } from 'node:stream';
import winston from 'winston';
import { env } from '../config/env';
import { hybridFormat } from './format';

fs.mkdirSync(env.logDir, { recursive: true });

const SECRET_KEYS = /api[_-]?key|password|authorization|token/i;

function redact(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [
      key,
      SECRET_KEYS.test(key) ? '[REDACTED]' : redact(entry)
    ]));
  }
  return value;
}

const redactFormat = winston.format((info) => {
  // Solo redactar si hay campos que coinciden con SECRET_KEYS.
  // CRÍTICO: retornar el info original si no hay cambios, sino Winston
  // puede descartar el mensaje completo.
  const hasSecrets = JSON.stringify(info).match(SECRET_KEYS);
  if (!hasSecrets) return info;
  return redact(info) as winston.Logform.TransformableInfo;
});
const logFormat = winston.format.combine(
  redactFormat(),
  // Timestamp con zona horaria local de México (America/Mexico_City).
  // El offset respecto a UTC se incluye en el ISO 8601 (ej. -06:00)
  // para que sea inequívoco. Si el server está en otra zona, Winston
  // usará la del sistema operativo. Para forzar México, ver más abajo.
  winston.format.timestamp({
    format: () => {
      const d = new Date();
      // Forzar a America/Mexico_City (CST/CDT según DST)
      const fmt = new Intl.DateTimeFormat('sv-SE', {
        timeZone: 'America/Mexico_City',
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', second: '2-digit',
        hour12: false
      });
      const parts = fmt.formatToParts(d);
      const get = (t: string) => parts.find(p => p.type === t)!.value;
      const tz = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Mexico_City', timeZoneName: 'shortOffset' }).formatToParts(d).find(p => p.type === 'timeZoneName')?.value || '-06:00';
      return `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}:${get('second')}${tz.replace('GMT', '')}`;
    }
  }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  hybridFormat()
);

/**
 * Writable stream que escribe a un archivo por día.
 * Cada día se abre un nuevo archivo automáticamente. Sin buffering.
 *
 * FIX CRÍTICO: Reemplaza a winston-daily-rotate-file porque esa librería
 * usa internamente un PassThrough que buffera los logs en procesos de
 * larga duración. Verificado: este stream SÍ escribe inmediatamente.
 */
class DailyFileStream extends Writable {
  private currentDate: string;
  private currentStream: fs.WriteStream | null = null;

  constructor(private readonly directory: string) {
    super({ decodeStrings: false });
    this.currentDate = this.todayString();
    this.openStream();
  }

  private todayString(): string {
    return new Date().toISOString().split('T')[0] ?? 'unknown';
  }

  private getFilePath(): string {
    return path.join(this.directory, `${this.currentDate}-middleware.log`);
  }

  private openStream(): void {
    if (this.currentStream) {
      this.currentStream.end();
    }
    const filePath = this.getFilePath();
    const fileIsNew = !fs.existsSync(filePath);
    this.currentStream = fs.createWriteStream(filePath, { flags: 'a' });
    // Cabecera SOLO cuando el archivo del día se crea por primera vez.
    // En arranques sucesivos del mismo día, el archivo ya existe y seguimos
    // en modo append sin duplicar la cabecera.
    if (fileIsNew) {
      const today = this.currentDate;
      const header = `═══════════════════════════════════════════════════════════════════\n  📅 ${today}  Valorflow Middleware\n═══════════════════════════════════════════════════════════════════\n\n`;
      this.currentStream.write(header);
    }
  }

  private checkRollover(): void {
    const today = this.todayString();
    if (today !== this.currentDate) {
      this.currentDate = today;
      this.openStream();
    }
  }

  override _write(chunk: Buffer, _encoding: string, callback: (error?: Error | null) => void): void {
    this.checkRollover();
    if (this.currentStream) {
      this.currentStream.write(chunk, callback);
    } else {
      callback();
    }
  }

  override _final(callback: (error?: Error | null) => void): void {
    if (this.currentStream) {
      this.currentStream.end(callback);
    } else {
      callback();
    }
  }
}

// Stream de archivo por día (DailyFileStream escribe cabecera al crear archivo nuevo).
const fileStream = new DailyFileStream(env.logDir);

const transport = new winston.transports.Stream({
  stream: fileStream,
  format: logFormat
});

export const logger = winston.createLogger({
  level: env.logLevel,
  format: logFormat,
  defaultMeta: { service: 'siemens-middleware' },
  transports: [transport, new winston.transports.Console()]
});

export function maskApiKey(key: string | undefined): string {
  if (!key) return '[NOT SET]';
  if (key.length <= 6) return '****';
  return `${key.slice(0, 3)}****${key.slice(-3)}`;
}

export function safeError(error: unknown): { name: string; message: string; status?: number } {
  if (error && typeof error === 'object') {
    const candidate = error as { name?: unknown; message?: unknown; response?: { status?: unknown } };
    const status = typeof candidate.response?.status === 'number' ? candidate.response.status : undefined;
    return {
      name: typeof candidate.name === 'string' ? candidate.name : 'Error',
      message: typeof candidate.message === 'string' ? candidate.message : 'Error no identificado',
      ...(status === undefined ? {} : { status })
    };
  }
  return { name: 'Error', message: String(error) };
}
