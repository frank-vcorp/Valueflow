import fs from 'node:fs';
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
  // API Key de Siemens: SIEMPRE desde variable de entorno. Nunca desde config.json
  // (config.json solo declara el marcador 'env:SIEMENS_API_KEY' como placeholder).
  siemensApiKey: process.env.SIEMENS_API_KEY ?? '',
  uiPort: port,
  uiUsername: required('UI_USERNAME', process.env.NODE_ENV === 'production' ? undefined : 'admin'),
  uiPasswordHash: required('UI_PASSWORD_HASH', process.env.NODE_ENV === 'production' ? undefined : '$2b$12$2AZ3st3kqRCZizqjy2S/OujFczGb0stAua7.CcpUXvtXqdN44kHv6'),
  logLevel: process.env.LOG_LEVEL ?? 'info',
  logDir: path.resolve(process.env.LOG_DIR ?? 'logs'),
  dataSource
} as const;

// Ruta física del archivo .env que dotenv acaba de cargar. Se usa para
// reescribir variables desde la UI (actualmente solo SIEMENS_API_KEY).
export const envFilePath = path.resolve(process.env.DOTENV_PATH ?? '.env');

/**
 * Actualiza (o inserta) una variable en el archivo .env sin tocar las demás.
 * Si la clave ya existe, reemplaza su valor. Si no, la agrega al final.
 * El archivo se reescribe con permisos 0o600 (lectura solo para el dueño).
 */
export function updateEnvVariable(name: string, value: string): void {
  const exists = fs.existsSync(envFilePath);
  const lines = exists ? fs.readFileSync(envFilePath, 'utf8').split(/\r?\n/) : [];
  const pattern = new RegExp(`^${name}=`);
  let replaced = false;
  const next = lines.map((line) => {
    if (pattern.test(line)) { replaced = true; return `${name}=${value}`; }
    return line;
  });
  if (!replaced) next.push(`${name}=${value}`);
  // Eliminar línea vacía final si quedó tras reemplazo, pero mantener salto final.
  while (next.length > 0 && next.at(-1) === '') next.pop();
  const tempPath = `${envFilePath}.tmp`;
  fs.writeFileSync(tempPath, `${next.join('\n')}\n`, { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(tempPath, envFilePath);
}
