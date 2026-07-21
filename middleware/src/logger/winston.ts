import fs from 'node:fs';
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { env } from '../config/env';

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

const redactFormat = winston.format((info) => redact(info) as winston.Logform.TransformableInfo);
const jsonFormat = winston.format.combine(
  redactFormat(),
  winston.format.timestamp(),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

const transport = new DailyRotateFile({
  dirname: env.logDir,
  filename: '%DATE%-middleware.log',
  datePattern: 'YYYY-MM-DD',
  maxFiles: '90d',
  maxSize: '20m',
  zippedArchive: true,
  format: jsonFormat
});

export const logger = winston.createLogger({
  level: env.logLevel,
  format: jsonFormat,
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
