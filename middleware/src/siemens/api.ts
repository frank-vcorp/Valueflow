import axios, { AxiosError } from 'axios';
import { readRuntimeConfig } from '../config/runtime';
import { logger, maskApiKey, safeError } from '../logger/winston';

export interface SendBatchResult { status: number; body: string; }
const sleep = (milliseconds: number): Promise<void> => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function sendBatch(payload: unknown[], endpoint: string): Promise<SendBatchResult> {
  const config = readRuntimeConfig();
  const apiKey = config.siemens.api_key;
  if (!apiKey) throw new Error('API Key no configurada. Configurar desde UI.');
  const url = `${config.siemens.base_url.replace(/\/$/, '')}/${config.siemens.environment}${endpoint}`;
  let delay = config.retry_policy.initial_delay_ms;
  for (let attempt = 1; attempt <= config.retry_policy.max_retries; attempt += 1) {
    try {
      const response = await axios.post(url, payload, {
        headers: { 'Content-Type': 'application/json', 'X-API-KEY': apiKey },
        timeout: 15_000
      });
      logger.info('Envío Siemens completado', { status: response.status, records: payload.length, key: maskApiKey(apiKey) });
      return { status: response.status, body: JSON.stringify(response.data) };
    } catch (error) {
      const axiosError = error as AxiosError;
      const status = axiosError.response?.status;
      if (status !== undefined && status >= 400 && status < 500) {
        logger.error('Siemens rechazó la petición; no se reintenta', { status, key: maskApiKey(apiKey) });
        throw error;
      }
      if (attempt === config.retry_policy.max_retries) {
        logger.error('Siemens agotó los reintentos', { status: status ?? 'TIMEOUT', attempts: attempt, error: safeError(error) });
        throw error;
      }
      logger.warn('Error temporal Siemens; reintentando', {
        status: status ?? 'TIMEOUT', attempt, max_retries: config.retry_policy.max_retries, retry_in_ms: delay
      });
      await sleep(delay);
      delay = Math.min(delay * config.retry_policy.backoff_multiplier, config.retry_policy.max_delay_ms);
    }
  }
  throw new Error('Flujo de reintentos Siemens terminó inesperadamente');
}

export async function testSiemensConnection(): Promise<number> {
  const config = readRuntimeConfig();
  const apiKey = config.siemens.api_key;
  if (!apiKey) throw new Error('API Key no configurada');

  // Test real: POST a /inventory/create_record con payload mínimo válido
  // Esperamos 4xx (validación de campos) = la API está respondiendo y autenticando correctamente
  const today = new Date().toISOString().split('T')[0];
  const testPayload = [{
    distributor_sender_id: config.siemens.distributor_sender_id,
    distributor_inventory_date: today,
    vendor_item_number: 'TEST-CONN',
    quantity: 1,
    quantity_unit_of_measure: 'PZA'
  }];
  const url = `${config.siemens.base_url.replace(/\/$/, '')}/${config.siemens.environment}/inventory/create_record`;
  const response = await axios.post(url, testPayload, {
    headers: { 'Content-Type': 'application/json', 'X-API-KEY': apiKey },
    timeout: 15_000,
    validateStatus: () => true
  });
  logger.info('Prueba de conexión Siemens ejecutada', { status: response.status, key: maskApiKey(apiKey) });
  return response.status;
}
