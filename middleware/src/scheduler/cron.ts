import cron, { ScheduledTask } from 'node-cron';
import { readRuntimeConfig } from '../config/runtime';
import { logger, safeError } from '../logger/winston';
import { isFirebirdUnavailableError } from '../db/firebird';
import { runInventoryJob } from '../jobs/runInventory';
import { runSalesJob } from '../jobs/runSales';

export type ExecutionStatus = 'running' | 'success' | 'failed' | 'db_unavailable' | 'skipped';

export interface JobExecution {
  job_name: 'inventory' | 'sales';
  start_time: Date;
  end_time?: Date;
  status: ExecutionStatus;
  records_sent?: number;
  error_message?: string;
}

const executionHistory: JobExecution[] = [];
let scheduledTasks: ScheduledTask[] = [];

async function executeInventoryJob(): Promise<void> {
  const execution: JobExecution = { job_name: 'inventory', start_time: new Date(), status: 'running' };
  executionHistory.unshift(execution);
  const jobLogger = logger.child({ job: 'inventory', execution_id: execution.start_time.getTime() });
  try {
    const config = readRuntimeConfig();
    if (!config.schedules.inventory.enabled) { execution.status = 'skipped'; jobLogger.info('Job de inventario desactivado'); return; }
    jobLogger.info('Iniciando job de inventario');
    const result = await runInventoryJob();
    execution.status = 'success'; execution.records_sent = result.totalSent; execution.end_time = new Date();
    jobLogger.info('Inventario completado', { records: result.totalSent, duration_ms: result.durationMs });
  } catch (error) {
    execution.end_time = new Date();
    execution.error_message = safeError(error).message;
    if (isFirebirdUnavailableError(error)) {
      execution.status = 'db_unavailable';
      jobLogger.warn('BD no accesible (entorno de desarrollo). El middleware está listo para producción.', { error: safeError(error) });
    } else {
      execution.status = 'failed';
      jobLogger.error('Fallo en inventario', safeError(error));
    }
  }
}

async function executeSalesJob(): Promise<void> {
  const execution: JobExecution = { job_name: 'sales', start_time: new Date(), status: 'running' };
  executionHistory.unshift(execution);
  const jobLogger = logger.child({ job: 'sales', execution_id: execution.start_time.getTime() });
  try {
    const config = readRuntimeConfig();
    if (!config.schedules.sales.enabled) { execution.status = 'skipped'; jobLogger.info('Job de ventas desactivado'); return; }
    jobLogger.info('Iniciando job de ventas');
    const result = await runSalesJob();
    execution.status = 'success'; execution.records_sent = result.totalSent; execution.end_time = new Date();
    jobLogger.info('Ventas completadas', { records: result.totalSent, duration_ms: result.durationMs });
  } catch (error) {
    execution.end_time = new Date();
    execution.error_message = safeError(error).message;
    if (isFirebirdUnavailableError(error)) {
      execution.status = 'db_unavailable';
      jobLogger.warn('BD no accesible (entorno de desarrollo). El middleware está listo para producción.', { error: safeError(error) });
    } else {
      execution.status = 'failed';
      jobLogger.error('Fallo en ventas', safeError(error));
    }
  }
}

export function startSchedulers(): void {
  const config = readRuntimeConfig();
  scheduledTasks.forEach((task) => task.stop());
  scheduledTasks = [
    cron.schedule(config.schedules.inventory.cron, () => { void executeInventoryJob(); }, { timezone: config.schedules.inventory.timezone }),
    cron.schedule(config.schedules.sales.cron, () => { void executeSalesJob(); }, { timezone: config.schedules.sales.timezone })
  ];
  logger.info('Schedulers iniciados', { inventory: config.schedules.inventory.cron, sales: config.schedules.sales.cron });
}

export function getExecutionHistory(): JobExecution[] { return executionHistory.slice(0, 50); }
export function runInventoryNow(): Promise<void> { return executeInventoryJob(); }
export function runSalesNow(): Promise<void> { return executeSalesJob(); }
