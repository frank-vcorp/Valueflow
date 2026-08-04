// IMPORTANTE: importar config/env PRIMERO para forzar la carga de dotenv
// antes de que el logger (u otros módulos) lean las variables de entorno.
// Este side-effect import garantiza que dotenv se ejecute ANTES de los
// requires de logger/ui/scheduler, que leen process.env al cargarse.
import './config/env';
import { startServer } from './ui/server';
import { startSchedulers } from './scheduler/cron';
import { logger, safeError } from './logger/winston';

try {
  startSchedulers();
  const server = startServer();
  const shutdown = (): void => {
    server.close(() => logger.info('UI detenida'));
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
} catch (error) {
  logger.error('No fue posible iniciar el middleware', safeError(error));
  process.exitCode = 1;
}
