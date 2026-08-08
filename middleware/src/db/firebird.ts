import * as Firebird from 'node-firebird';
import { readRuntimeConfig } from '../config/runtime';
import { env } from '../config/env';
import { logger, safeError } from '../logger/winston';

interface FirebirdOptions {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  // FIX-20260807-02: charset explicito. La BD Aspel SAE usa ISO8859_1
  // (verificado con FlameRobin 2026-08-07). Sin esto, node-firebird
  // defaultea a NONE y el servidor Firebird emite warning
  // "Database charset: ISO8859_1 is different from connection charset: NONE".
  // Ademas, sin charset correcto, las queries retornan strings con
  // caracteres ilegibles en columnas con acentos/eñes.
  charset?: string;
}

/**
 * Pool de conexiones Firebird basado en `node-firebird` (clásico, sin bindings nativos).
 *
 * Migración desde `node-firebird-driver-native` (v3.6.0) — el driver nativo requería
 * MSVC Build Tools para compilar vía node-gyp y no podía instalarse en la VM Windows
 * de Frank. El driver clásico usa solo JS puro y dependencias puras JS (big-integer,
 * long), por lo que funciona en cualquier plataforma sin compilador.
 *
 * API pública preservada (consumida por `db/queries/inventory.ts`, `db/queries/sales.ts`,
 * `ui/server.ts` y `scheduler/cron.ts`):
 *   - pool.query<T>(sql, params) → Promise<T[]>
 *   - pool.testConnection() → Promise<void>
 *   - pool.close() → Promise<void>
 *   - isFirebirdUnavailableError(error) → boolean
 *
 * Notas técnicas:
 *   - `Firebird.pool(max, opts)` crea el pool nativo del driver clásico.
 *   - `pool.get(cb)` obtiene una `Database`; al llamar `db.detach()` la conexión
 *     regresa al pool (no se desconecta realmente).
 *   - `db.execute(sql, params, cb, { asObject: false })` se usa en lugar de
 *     `db.query(...)` para conservar filas indexadas por columna (compat con
 *     `inventory.ts` y `sales.ts` que esperan `row[0]`, `row[1]`, …).
 *   - `node-firebird` no expone `READ_ONLY` / `NO_WAIT` / `TransactionIsolation` a
 *     nivel de query (cada query abre su propia transacción implícita). Si se
 *     requiere `READ_ONLY` en producción, debe configurarse a nivel del usuario
 *     Firebird en la BD (permisos), no en código.
 */
class FirebirdPool {
  private pool: Firebird.ConnectionPool | null = null;
  // IMPL-20260806-05: max=3 conexiones (suficiente para 2 jobs concurrentes + 1 buffer).
  // Mismo límite que el driver nativo usaba para evitar saturación en jobs paralelos.
  readonly maxConnections = 3;
  readonly timeoutMs = 30_000;

  constructor() {
    // El pool se crea lazy en el primer query, permitiendo levantar la UI sin BD local.
  }

  private options(): FirebirdOptions {
    const db = readRuntimeConfig().firebird;
    return {
      host: '127.0.0.1',
      port: 3050,
      database: db.db_path,
      user: db.user,
      password: env.firebirdPassword,
      charset: 'ISO8859_1',
    };
  }

  private getPool(): Firebird.ConnectionPool {
    if (!this.pool) {
      this.pool = Firebird.pool(this.maxConnections, this.options());
    }
    return this.pool;
  }

  // IMPL-20260806-05: node-firebird maneja el pool internamente. acquire/release
  // se reducen a: pool.get(cb) → usar db → db.detach() (vuelve al pool).
  private acquire(): Promise<Firebird.Database> {
    return new Promise((resolve, reject) => {
      this.getPool().get((err, db) => {
        if (err) {
          reject(err instanceof Error ? err : new Error(String(err)));
          return;
        }
        if (!db) {
          reject(new Error('Pool Firebird no devolvió conexión'));
          return;
        }
        resolve(db);
      });
    });
  }

  private release(db: Firebird.Database): void {
    try {
      // En conexiones pool'eadas, detach() devuelve la conexión al pool en lugar
      // de cerrarla realmente. Forzamos cierre solo si la conexión está marcada
      // como unusable por el driver.
      db.detach();
    } catch {
      // Ignorar errores: detach puede ser no-op o fallar si la conexión ya cayó.
    }
  }

  private discard(db: Firebird.Database): void {
    this.release(db);
  }

  async query<T = unknown[]>(sql: string, parameters: unknown[] = []): Promise<T[]> {
    const started = Date.now();
    let lastError: Error | undefined;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      let db: Firebird.Database | undefined;
      try {
        db = await this.acquire();
        const rows = await new Promise<T[]>((resolve, reject) => {
          // FIX-20260807-04: NO extraer `const execute = db.execute` antes de
          // invocarlo. node-firebird@1.1.10 accede a `self.connection` internamente
          // y rompe cuando el método se llama desvinculado del objeto (`this` se pierde).
          // Llamar directamente `db.execute(...)` preserva el binding.
          // asObject:false → filas como arrays indexados (row[0], row[1], …),
          // retrocompatible con los consumidores inventory.ts y sales.ts.
          const params = Array.isArray(parameters) ? parameters : [parameters];
          db!.execute(
            sql,
            params,
            (err: unknown, result: unknown) => {
              if (err) {
                reject(err instanceof Error ? err : new Error(String(err)));
                return;
              }
              resolve(result as T[]);
            },
            { asObject: false }
          );
        });
        if (Date.now() - started > 5000) {
          logger.warn('Query Firebird lenta', { duration_ms: Date.now() - started, rows: rows.length });
        }
        return rows;
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(String(error));
        logger.warn('Error en query Firebird; reintentando', { attempt, error: safeError(error) });
        // IMPL-20260806-05: backoff entre reintentos para no saturar el pool.
        // retry 1 → 500ms, retry 2 → 1000ms, retry 3 → 1500ms.
        await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
      } finally {
        if (db) this.release(db);
      }
    }
    throw lastError ?? new Error('Error desconocido en query Firebird');
  }

  async testConnection(): Promise<void> {
    await this.query('SELECT FIRST 1 * FROM RDB$DATABASE');
  }

  async close(): Promise<void> {
    if (this.pool) {
      const pool = this.pool;
      this.pool = null;
      await new Promise<void>((resolve) => {
        pool.destroy(() => resolve());
      });
    }
  }
}

export const pool = new FirebirdPool();

/**
 * Detecta si un error corresponde al módulo Firebird no disponible.
 *
 * Cubre tanto el driver nativo (node-firebird-driver-native, ya no se usa como
 * primario pero sigue instalado) como el driver clásico (node-firebird), en caso
 * de que falten binarios, fbclient.dll, o haya un fallo de inicialización del
 * socket al puerto 3050. Distingue este caso del error real para que el dashboard
 * no muestre "failed" cuando el problema es del entorno, no del software.
 */
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
    'libfbclient',
    'node-firebird',
    'cannot find module',
    'node-gyp',
    'econnrefused',
    'connection refused',
    'fbclient',
    'service attach'
  ];

  return patterns.some((pattern) => message.includes(pattern));
}