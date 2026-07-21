import fs from 'node:fs';
import path from 'node:path';
import express, { type NextFunction, type Request, type Response } from 'express';
import bcrypt from 'bcryptjs';
import { env } from '../config/env';
import { getConfigLastModified, getConfigPath, readRuntimeConfig, validateRuntimeConfig, writeRuntimeConfig, type RuntimeConfig } from '../config/runtime';
import { maskApiKey, logger, safeError } from '../logger/winston';
import { getExecutionHistory, runInventoryNow, runSalesNow } from '../scheduler/cron';
import { pool } from '../db/firebird';
import { testSiemensConnection } from '../siemens/api';

const viewsDir = path.resolve(__dirname, 'views');
const publicDir = path.resolve(process.cwd(), 'public');
const escapeHtml = (value: unknown): string => String(value ?? '').replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character] ?? character));

function render(name: string, replacements: Record<string, string> = {}): string {
  const content = fs.readFileSync(path.join(viewsDir, `${name}.html`), 'utf8');
  const page = Object.entries(replacements).reduce((html, [key, value]) => html.replaceAll(`{{${key}}}`, value), content);
  const config = readRuntimeConfig();
  const layout = fs.readFileSync(path.join(viewsDir, 'layout.html'), 'utf8');
  return layout.replace('{{title}}', name).replace('{{environment}}', escapeHtml(config.siemens.environment)).replace('{{content}}', page);
}

function basicAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Basic ')) { res.setHeader('WWW-Authenticate', 'Basic realm="Siemens Middleware"'); res.status(401).send('Autenticación requerida'); return; }
  const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
  const separator = decoded.indexOf(':');
  const username = separator >= 0 ? decoded.slice(0, separator) : '';
  const password = separator >= 0 ? decoded.slice(separator + 1) : '';
  if (username !== env.uiUsername || !bcrypt.compareSync(password, env.uiPasswordHash)) { res.status(401).send('Credenciales inválidas'); return; }
  res.locals.authUser = username;
  next();
}

function statusCard(job: 'inventory' | 'sales'): string {
  const execution = getExecutionHistory().find((item) => item.job_name === job);
  const label = job === 'inventory' ? 'Inventario' : 'Ventas';
  const status = execution?.status ?? 'sin ejecución';
  return `<article class="bg-white rounded-lg shadow p-5"><h2 class="font-semibold text-lg">${label}</h2><p class="mt-2">Estado: <strong>${escapeHtml(status)}</strong></p><p class="text-sm text-slate-500">Registros enviados: ${execution?.records_sent ?? 0}</p><p class="text-sm text-slate-500">Última ejecución: ${execution?.start_time.toLocaleString('es-MX') ?? 'N/A'}</p></article>`;
}

function createServer(): express.Express {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));
  app.use('/images', express.static(publicDir));
  app.use((req, res, next) => basicAuth(req, res, next));

  app.get('/', (_req, res) => {
    const history = getExecutionHistory().map((item) => `<tr class="border-t"><td class="p-2">${escapeHtml(item.job_name)}</td><td class="p-2">${escapeHtml(item.status)}</td><td class="p-2">${item.records_sent ?? 0}</td><td class="p-2">${item.start_time.toLocaleString('es-MX')}</td></tr>`).join('');
    res.send(render('dashboard', { cards: statusCard('inventory') + statusCard('sales'), history: `<div class="overflow-auto"><table class="w-full text-sm"><thead><tr><th class="text-left p-2">Job</th><th class="text-left p-2">Estado</th><th class="text-left p-2">Registros</th><th class="text-left p-2">Inicio</th></tr></thead><tbody>${history || '<tr><td class="p-2" colspan="4">Sin ejecuciones.</td></tr>'}</tbody></table></div>` }));
  });

  app.get('/config', (_req, res) => {
    const config = readRuntimeConfig();
    const optionalInventory = Object.entries(config.optional_fields.inventory).map(([key, value]) => `<label><input type="checkbox" name="optional_inventory_${escapeHtml(key)}" ${value ? 'checked' : ''}> ${escapeHtml(key)}</label>`).join('');
    const optionalSales = Object.entries(config.optional_fields.sales).map(([key, value]) => `<label><input type="checkbox" name="optional_sales_${escapeHtml(key)}" ${value ? 'checked' : ''}> ${escapeHtml(key)}</label>`).join('');
    const fields = `<div class="grid md:grid-cols-2 gap-4"><label>Base URL<input name="base_url" value="${escapeHtml(config.siemens.base_url)}" class="border rounded px-3 py-2 w-full"></label><label>Ambiente<input name="environment" value="${escapeHtml(config.siemens.environment)}" class="border rounded px-3 py-2 w-full"></label><label>Sender ID<input name="distributor_sender_id" value="${escapeHtml(config.siemens.distributor_sender_id)}" class="border rounded px-3 py-2 w-full"></label><label>Tamaño batch<input name="batch_size" type="number" min="1" max="3000" value="${config.batch_size}" class="border rounded px-3 py-2 w-full"></label></div><label class="block">Líneas Siemens (separadas por coma)<input name="lines" value="${escapeHtml(config.siemens_line_filter.lines.join(', '))}" class="border rounded px-3 py-2 w-full"></label><div class="grid md:grid-cols-2 gap-4"><label><input type="checkbox" name="inventory_enabled" ${config.schedules.inventory.enabled ? 'checked' : ''}> Inventario habilitado (${escapeHtml(config.schedules.inventory.cron)})</label><label><input type="checkbox" name="sales_enabled" ${config.schedules.sales.enabled ? 'checked' : ''}> Ventas habilitadas (${escapeHtml(config.schedules.sales.cron)})</label></div><fieldset><legend class="font-semibold">Campos opcionales inventario</legend><div class="grid md:grid-cols-3 gap-2">${optionalInventory}</div></fieldset><fieldset><legend class="font-semibold">Campos opcionales ventas</legend><div class="grid md:grid-cols-3 gap-2">${optionalSales}</div></fieldset>`;
    const modified = getConfigLastModified()?.toLocaleString('es-MX') ?? 'No creado; usando ejemplo';
    res.send(render('config', { fields, keyPreview: escapeHtml(maskApiKey(config.siemens.api_key)), lastUpdated: escapeHtml(modified) }));
  });

  app.get('/actions', (_req, res) => res.send(render('actions', { buttons: `<button hx-post="/api/actions/inventory" hx-target="#result" class="bg-blue-700 text-white rounded px-4 py-3">Ejecutar Inventario ahora</button><button hx-post="/api/actions/sales" hx-target="#result" class="bg-blue-700 text-white rounded px-4 py-3">Ejecutar Ventas ahora</button><button hx-post="/api/actions/test-siemens" hx-target="#result" class="bg-slate-700 text-white rounded px-4 py-3">Test conexión Siemens</button><button hx-post="/api/actions/test-sae" hx-target="#result" class="bg-slate-700 text-white rounded px-4 py-3">Test conexión SAE</button>` })));
  app.get('/logs', (_req, res) => {
    const files = fs.readdirSync(env.logDir).filter((file) => file.endsWith('.log') || file.endsWith('.gz')).map((file) => `<li>${escapeHtml(file)}</li>`).join('');
    res.send(render('logs', { files: files || '<li>Sin archivos de log todavía.</li>' }));
  });
  app.get('/diagnostics', (_req, res) => res.send(render('diagnostics', { diagnostics: `<p>Node.js: ${escapeHtml(process.version)}</p><p>Driver: node-firebird-native-api mediante node-firebird-driver-native</p><p>BD configurada: ${escapeHtml(readRuntimeConfig().firebird.db_path)}</p><p>API Key: ${escapeHtml(maskApiKey(readRuntimeConfig().siemens.api_key))}</p><p>Config: ${escapeHtml(getConfigPath())}</p>` })));

  app.get('/api/config', (_req, res) => { const config = readRuntimeConfig(); res.json({ ...config, siemens: { ...config.siemens, api_key: maskApiKey(config.siemens.api_key) } }); });
  app.post('/api/config', (req, res) => {
    try {
      const current = readRuntimeConfig();
      const body = req.body as Record<string, unknown>;
      const optionalInventory = Object.fromEntries(Object.keys(current.optional_fields.inventory).map((key) => [key, body[`optional_inventory_${key}`] === true || body[`optional_inventory_${key}`] === 'on']));
      const optionalSales = Object.fromEntries(Object.keys(current.optional_fields.sales).map((key) => [key, body[`optional_sales_${key}`] === true || body[`optional_sales_${key}`] === 'on']));
      const config: RuntimeConfig = { ...current, siemens: { ...current.siemens, base_url: String(body.base_url ?? current.siemens.base_url), environment: String(body.environment ?? current.siemens.environment), distributor_sender_id: String(body.distributor_sender_id ?? current.siemens.distributor_sender_id) }, batch_size: Number(body.batch_size ?? current.batch_size), siemens_line_filter: { ...current.siemens_line_filter, lines: String(body.lines ?? current.siemens_line_filter.lines.join(',')).split(',').map((line) => line.trim()).filter(Boolean) }, schedules: { ...current.schedules, inventory: { ...current.schedules.inventory, enabled: body.inventory_enabled === true || body.inventory_enabled === 'on' }, sales: { ...current.schedules.sales, enabled: body.sales_enabled === true || body.sales_enabled === 'on' } }, optional_fields: { inventory: optionalInventory, sales: optionalSales } };
      validateRuntimeConfig(config); writeRuntimeConfig(config); logger.info('Configuración operativa actualizada', { updated_by: res.locals.authUser });
      res.json({ success: true });
    } catch (error) { res.status(400).json({ error: safeError(error).message }); }
  });
  app.post('/api/config/siemens-key', (req, res) => {
    const apiKey = String(req.body.api_key ?? '');
    if (apiKey.length < 32) { res.status(400).json({ error: 'API Key inválida (mínimo 32 caracteres)' }); return; }
    const config = readRuntimeConfig(); config.siemens.api_key = apiKey; writeRuntimeConfig(config);
    logger.info('API Key actualizada por usuario', { key_last4: apiKey.slice(-4), updated_by: res.locals.authUser });
    res.json({ success: true, key_preview: maskApiKey(apiKey), next_execution_will_use_new_key: true });
  });
  app.post('/api/actions/inventory', async (_req, res) => { await runInventoryNow(); res.send('<p class="text-green-700">Job de inventario terminado. Revise el dashboard.</p>'); });
  app.post('/api/actions/sales', async (_req, res) => { await runSalesNow(); res.send('<p class="text-green-700">Job de ventas terminado. Revise el dashboard.</p>'); });
  app.post('/api/actions/test-siemens', async (_req, res) => { try { const status = await testSiemensConnection(); res.send(`<p>Siemens respondió HTTP ${status}.</p>`); } catch (error) { res.status(502).send(`<p class="text-red-700">Error Siemens: ${escapeHtml(safeError(error).message)}</p>`); } });
  app.post('/api/actions/test-sae', async (_req, res) => { try { await pool.testConnection(); res.send('<p class="text-green-700">Conexión SAE disponible.</p>'); } catch (error) { res.status(503).send(`<p class="text-red-700">Error Firebird: ${escapeHtml(safeError(error).message)}</p>`); } });
  app.get('/api/logs/download', (_req, res) => { const files = fs.readdirSync(env.logDir).filter((file) => file.endsWith('.log')).sort(); const file = files.at(-1); if (!file) { res.status(404).send('No hay logs'); return; } res.download(path.join(env.logDir, file)); });
  app.use((_req, res) => res.status(404).send('No encontrado'));
  return app;
}

export function startServer(): ReturnType<express.Express['listen']> { return createServer().listen(env.uiPort, '127.0.0.1', () => logger.info('UI iniciada', { address: `http://localhost:${env.uiPort}` })); }
export { createServer };
