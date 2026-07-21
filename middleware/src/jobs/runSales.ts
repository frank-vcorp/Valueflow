import { fetchSalesByDate } from '../db/queries/sales';
import { transformSales } from '../siemens/sales';
import { sendBatch } from '../siemens/api';
import { readRuntimeConfig } from '../config/runtime';
import { logger } from '../logger/winston';
import type { JobResult } from './runInventory';

export async function runSalesJob(date = new Date(Date.now() - 86_400_000)): Promise<JobResult> {
  const started = Date.now();
  const config = readRuntimeConfig();
  const records = await fetchSalesByDate(date);
  const payload = transformSales(records);
  if (records.length > 0 && payload.length === 0) logger.debug('Factura(s) sin líneas Siemens tras filtro; omitida(s)');
  if (payload.length === 0) return { totalSent: 0, durationMs: Date.now() - started };
  await sendBatch(payload.slice(0, config.batch_size), '/create_record');
  if (payload.length > config.batch_size) {
    for (let offset = config.batch_size; offset < payload.length; offset += config.batch_size) {
      await sendBatch(payload.slice(offset, offset + config.batch_size), '/create_record');
    }
  }
  return { totalSent: payload.length, durationMs: Date.now() - started };
}
