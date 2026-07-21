import fs from 'node:fs';
import path from 'node:path';

export const SIEMENS_LINES = [
  'BAJA', 'SINU', 'SIMAT', 'LP', 'DRIVE', 'MOTOR', 'SINUM', 'SERVI', 'OBSO',
  'SENSO', 'SERVO', 'INSTR', 'UPS', 'SIMA', 'ESPE'
] as const;

export interface ScheduleConfig {
  enabled: boolean;
  cron: string;
  timezone: string;
}

export interface RuntimeConfig {
  siemens: {
    base_url: string;
    api_key: string;
    environment: string;
    distributor_sender_id: string;
  };
  firebird: {
    db_path: string;
    user: string;
    password_source: 'env:FIREBIRD_PASSWORD';
  };
  schedules: {
    inventory: ScheduleConfig;
    sales: ScheduleConfig;
  };
  batch_size: number;
  retry_policy: {
    max_retries: number;
    initial_delay_ms: number;
    backoff_multiplier: number;
    max_delay_ms: number;
  };
  siemens_line_filter: {
    enabled: boolean;
    lines: string[];
    include_inactive_products: boolean;
  };
  optional_fields: {
    inventory: Record<string, boolean>;
    sales: Record<string, boolean>;
  };
}

const configPath = path.resolve(process.env.CONFIG_PATH ?? 'config.json');
const examplePath = path.resolve('config.json.example');

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function validateRuntimeConfig(value: unknown): asserts value is RuntimeConfig {
  if (!isObject(value) || !isObject(value.siemens) || !isObject(value.firebird) ||
      !isObject(value.schedules) || !isObject(value.retry_policy) ||
      !isObject(value.siemens_line_filter) || !isObject(value.optional_fields)) {
    throw new Error('config.json no contiene la estructura requerida');
  }
  const siemens = value.siemens;
  const firebird = value.firebird;
  const schedules = value.schedules;
  const retry = value.retry_policy;
  const filter = value.siemens_line_filter;
  if (typeof siemens.base_url !== 'string' || typeof siemens.api_key !== 'string' ||
      typeof siemens.environment !== 'string' || typeof siemens.distributor_sender_id !== 'string') {
    throw new Error('Configuración Siemens inválida');
  }
  if (typeof firebird.db_path !== 'string' || typeof firebird.user !== 'string' ||
      firebird.password_source !== 'env:FIREBIRD_PASSWORD') {
    throw new Error('Configuración Firebird inválida');
  }
  for (const job of ['inventory', 'sales'] as const) {
    const schedule = schedules[job];
    if (!isObject(schedule) || typeof schedule.enabled !== 'boolean' ||
        typeof schedule.cron !== 'string' || typeof schedule.timezone !== 'string') {
      throw new Error(`Schedule ${job} inválido`);
    }
  }
  if (!Number.isInteger(value.batch_size) || (value.batch_size as number) < 1 || (value.batch_size as number) > 3000) {
    throw new Error('batch_size debe ser entero entre 1 y 3000');
  }
  if (!Number.isInteger(retry.max_retries) || (retry.max_retries as number) < 1 ||
      typeof retry.initial_delay_ms !== 'number' || typeof retry.backoff_multiplier !== 'number' ||
      typeof retry.max_delay_ms !== 'number') {
    throw new Error('Política de reintentos inválida');
  }
  if (typeof filter.enabled !== 'boolean' || !Array.isArray(filter.lines) ||
      !filter.lines.every((line) => typeof line === 'string' && line.trim().length > 0) ||
      typeof filter.include_inactive_products !== 'boolean') {
    throw new Error('Filtro de líneas Siemens inválido');
  }
}

export function readRuntimeConfig(): RuntimeConfig {
  const source = fs.existsSync(configPath) ? configPath : examplePath;
  const parsed: unknown = JSON.parse(fs.readFileSync(source, 'utf8'));
  validateRuntimeConfig(parsed);
  return parsed;
}

export function writeRuntimeConfig(config: RuntimeConfig): void {
  validateRuntimeConfig(config);
  const tempPath = `${configPath}.tmp`;
  fs.writeFileSync(tempPath, `${JSON.stringify(config, null, 2)}\n`, { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(tempPath, configPath);
}

export function getConfigLastModified(): Date | undefined {
  if (!fs.existsSync(configPath)) return undefined;
  return fs.statSync(configPath).mtime;
}

export function getConfigPath(): string {
  return configPath;
}
