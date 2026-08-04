import path from 'node:path';
import dotenv from 'dotenv';

dotenv.config();

function required(name: string, developmentFallback?: string): string {
  const value = process.env[name] ?? developmentFallback;
  if (!value) throw new Error(`Variable de entorno requerida no configurada: ${name}`);
  return value;
}

const port = Number(process.env.UI_PORT ?? 4567);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('UI_PORT debe ser un puerto válido');

// dataSource: 'production' (cliente Windows, datos reales) | 'qa' (testing) | 'demo' (sintético).
// Default seguro: 'demo'. En producción debe configurarse DATA_SOURCE=production en .env.
const rawDataSource = (process.env.DATA_SOURCE ?? 'demo').toLowerCase();
const dataSource: 'production' | 'qa' | 'demo' =
  rawDataSource === 'production' || rawDataSource === 'qa' ? rawDataSource : 'demo';

export const env = {
  firebirdPassword: process.env.FIREBIRD_PASSWORD ?? '',
  firebirdClientLibrary: process.env.FIREBIRD_CLIENT_LIBRARY,
  uiPort: port,
  uiUsername: required('UI_USERNAME', process.env.NODE_ENV === 'production' ? undefined : 'admin'),
  uiPasswordHash: required('UI_PASSWORD_HASH', process.env.NODE_ENV === 'production' ? undefined : '$2b$12$2AZ3st3kqRCZizqjy2S/OujFczGb0stAua7.CcpUXvtXqdN44kHv6'),
  logLevel: process.env.LOG_LEVEL ?? 'info',
  logDir: path.resolve(process.env.LOG_DIR ?? 'logs'),
  dataSource
} as const;
