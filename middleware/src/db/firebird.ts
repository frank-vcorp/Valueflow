import { createRequire } from 'node:module';
import type { Attachment, Client, Transaction } from 'node-firebird-driver';
import { DatabaseReadWriteMode, TransactionIsolation } from 'node-firebird-driver';
import { readRuntimeConfig } from '../config/runtime';
import { env } from '../config/env';
import { logger, safeError } from '../logger/winston';

interface PooledAttachment { attachment: Attachment; busy: boolean; }

class FirebirdPool {
  private client?: Client;
  private readonly connections: PooledAttachment[] = [];
  private waiters: Array<(connection: PooledAttachment) => void> = [];
  // FIX IMPL-20260806-04: maxConnections=3 (suficiente para 2 jobs concurrentes + 1 buffer)
  // — antes 5 saturaba el pool en jobs paralelos.
  private readonly maxConnections = 3;
  private readonly timeoutMs = 30_000;

  constructor() {
    // El addon nativo se carga al primer acceso, permitiendo levantar la UI sin BD local.
  }

  private getClient(): Client {
    if (!this.client) {
      const require = createRequire(__filename);
      const native = require('node-firebird-driver-native') as typeof import('node-firebird-driver-native');
      const library = env.firebirdClientLibrary ?? native.getDefaultLibraryFilename();
      this.client = native.createNativeClient(library);
    }
    return this.client;
  }

  private uri(): string {
    const dbPath = readRuntimeConfig().firebird.db_path;
    return `localhost/3050:${dbPath}`;
  }

  private async createConnection(): Promise<PooledAttachment> {
    const db = readRuntimeConfig().firebird;
    const connection = await this.getClient().connect(this.uri(), {
      username: db.user,
      password: env.firebirdPassword,
      setDatabaseReadWriteMode: DatabaseReadWriteMode.READ_ONLY
    });
    const pooled = { attachment: connection, busy: false };
    this.connections.push(pooled);
    return pooled;
  }

  private async acquire(): Promise<PooledAttachment> {
    const idle = this.connections.find((connection) => !connection.busy);
    if (idle) { idle.busy = true; return idle; }
    if (this.connections.length < this.maxConnections) {
      const connection = await this.createConnection();
      connection.busy = true;
      return connection;
    }
    return new Promise((resolve) => { this.waiters.push((connection) => { connection.busy = true; resolve(connection); }); });
  }

  private release(connection: PooledAttachment): void {
    connection.busy = false;
    const waiter = this.waiters.shift();
    if (waiter) waiter(connection);
  }

  private async discard(connection: PooledAttachment): Promise<void> {
    const index = this.connections.indexOf(connection);
    if (index >= 0) this.connections.splice(index, 1);
    try { await connection.attachment.disconnect(); } catch (error) { logger.warn('No fue posible cerrar conexión Firebird', safeError(error)); }
  }

  async query<T>(sql: string, parameters: unknown[] = []): Promise<T[]> {
    const started = Date.now();
    let lastError: unknown;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      let connection: PooledAttachment | undefined;
      let transaction: Transaction | undefined;
      try {
        connection = await this.acquire();
        // FIX IMPL-20260806-04: NO_WAIT evita bloqueos cuando inventory + sales
        // se disparan a la vez desde la UI. Si la tabla está lockeada falla
        // rápido (lock-conflict) y el retry loop con backoff lo recupera.
        // READ_COMMITTED (+RECORD_VERSION) asegura que solo se leen commits
        // confirmados sin bloquearse por transacciones concurrentes.
        transaction = await connection.attachment.startTransaction({
          accessMode: 'READ_ONLY',
          waitMode: 'NO_WAIT',
          isolation: TransactionIsolation.READ_COMMITTED,
          readCommittedMode: 'RECORD_VERSION'
        });
        const resultSet = await Promise.race([
          connection.attachment.executeQuery(transaction, sql, parameters),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('Timeout Firebird de 60 segundos')), this.timeoutMs * 2))
        ]);
        // FIX IMPL-20260806-04: streaming chunks de 1000 filas. fetch() bloqueante
        // podía agotar el timeout del server Firebird en queries grandes (inventario
        // ~8000 productos). Los chunks liberan la transacción temprano si fuera
        // necesario y permiten al event loop procesar otras señales.
        // API real: fetch({ fetchSize }) — fetchSize es el batch size de filas.
        const rows: unknown[][] = [];
        let chunk: unknown[][];
        do {
          chunk = await Promise.race([
            resultSet.fetch({ fetchSize: 1000 }),
            new Promise<never>((_, reject) => setTimeout(() => reject(new Error('Timeout fetch')), this.timeoutMs * 2))
          ]) as unknown[][];
          rows.push(...chunk);
        } while (chunk.length === 1000);
        await resultSet.close();
        await transaction.commit();
        if (Date.now() - started > 5000) logger.warn('Query Firebird lenta', { duration_ms: Date.now() - started, rows: rows.length });
        return rows as T[];
      } catch (error) {
        lastError = error;
        if (transaction) { try { await transaction.rollback(); } catch { /* conexión caída */ } }
        if (connection) await this.discard(connection);
        logger.warn('Error en query Firebird; reintentando', { attempt, error: safeError(error) });
        // FIX IMPL-20260806-04: backoff entre reintentos para no saturar el pool.
        // retry 1 → 500ms, retry 2 → 1000ms, retry 3 → 1500ms.
        await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
      } finally {
        if (connection && this.connections.includes(connection)) this.release(connection);
      }
    }
    throw lastError instanceof Error ? lastError : new Error(String(lastError));
  }

  async testConnection(): Promise<void> {
    await this.query('SELECT 1 FROM RDB$DATABASE');
  }

  async close(): Promise<void> {
    await Promise.all(this.connections.map((connection) => connection.attachment.disconnect()));
    this.connections.length = 0;
    if (this.client) await this.client.dispose();
  }
}

export const pool = new FirebirdPool();

/**
 * Detecta si un error corresponde al módulo nativo de Firebird no disponible
 * (típico en Linux donde node-gyp no compila). Distingue este caso del error
 * real para que el dashboard no muestre "failed" cuando el problema es del
 * entorno de desarrollo, no del software.
 *
 * Implementación: por mensaje del error (string includes, case-insensitive).
 * Decisión técnica confirmada en SPEC-IMPL-20260804-01 §3 y §5.
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
    'compiled/',
    'node-firebird',
    'addon.node',
    'cannot find module',
    'node-gyp'
  ];

  return patterns.some((pattern) => message.includes(pattern));
}
