import { fetchInventorySnapshot } from '../db/queries/inventory';
import { transformInventory } from '../siemens/inventory';
import { sendBatch } from '../siemens/api';
import { readRuntimeConfig } from '../config/runtime';
import { logger } from '../logger/winston';

export interface JobResult { totalSent: number; durationMs: number; }

export async function runInventoryJob(): Promise<JobResult> {
  const started = Date.now();
  const config = readRuntimeConfig();
  const payload = transformInventory(await fetchInventorySnapshot());
  let totalSent = 0;
  for (let offset = 0; offset < payload.length; offset += config.batch_size) {
    const batch = payload.slice(offset, offset + config.batch_size);
    await sendBatch(batch, '/inventory/create_record');
    totalSent += batch.length;
  }
  if (totalSent > 5000) logger.warn('Inventario excede 5000 registros', { records: totalSent });
  return { totalSent, durationMs: Date.now() - started };
}
