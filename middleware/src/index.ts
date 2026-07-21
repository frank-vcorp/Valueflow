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
