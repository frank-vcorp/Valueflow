import { createRequire } from 'node:module';
import type { Attachment, Client, Transaction } from 'node-firebird-driver';
import { DatabaseReadWriteMode } from 'node-firebird-driver';
import { readRuntimeConfig } from '../config/runtime';
import { env } from '../config/env';
import { logger, safeError } from '../logger/winston';

interface PooledAttachment { attachment: Attachment; busy: boolean; }

class FirebirdPool {
  private client?: Client;
  private readonly connections: PooledAttachment[] = [];
  private waiters: Array<(connection: PooledAttachment) => void> = [];
  private readonly maxConnections = 5;
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
        transaction = await connection.attachment.startTransaction({ accessMode: 'READ_ONLY', waitMode: 'WAIT' });
        const resultSet = await Promise.race([
          connection.attachment.executeQuery(transaction, sql, parameters),
          new Promise<never>((_, reject) => setTimeout(() => reject(new Error('Timeout Firebird de 30 segundos')), this.timeoutMs))
        ]);
        const rows = await resultSet.fetch();
        await resultSet.close();
        await transaction.commit();
        if (Date.now() - started > 5000) logger.warn('Query Firebird lenta', { duration_ms: Date.now() - started });
        return rows as T[];
      } catch (error) {
        lastError = error;
        if (transaction) { try { await transaction.rollback(); } catch { /* conexión caída */ } }
        if (connection) await this.discard(connection);
        logger.warn('Error en query Firebird; reintentando', { attempt, error: safeError(error) });
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
