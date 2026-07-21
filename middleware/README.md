# Middleware Repaga — Siemens PoSi

Middleware local para leer inventario y ventas de Aspel SAE 10 (Firebird) y enviarlos a Siemens PoSi. La implementación usa Node.js 20 LTS, TypeScript, Express, HTMX, Tailwind CDN, Winston y `node-firebird-native-api` mediante su cliente nativo de alto nivel.

## Instalación local

Requisitos: Node.js 20 LTS y, en Windows del cliente, el `fbclient.dll` incluido con Firebird/SAE 10.

```bash
npm install
cp .env.example .env
cp config.json.example config.json
npm run build
npm start
```

La UI queda disponible en `http://localhost:4567`. Solo escucha en `127.0.0.1` y requiere HTTP Basic Auth. Defina `UI_USERNAME`, `UI_PASSWORD_HASH` y `FIREBIRD_PASSWORD` en `.env` antes de operar. Para generar un hash bcrypt:

```bash
node -e "console.log(require('bcryptjs').hashSync('CAMBIE_ESTA_CLAVE', 12))"
```

En `config.json` configure la ruta real de SAE, usuario de solo lectura, URL/ambiente Siemens y API Key. La API Key es operativa y editable desde Configuración; no se copia a `.env`.

## Operación

- Inventario: cron independiente, por defecto `02:00`, en batches de máximo 3,000.
- Ventas: cron independiente, por defecto `03:00`, consulta el día anterior.
- Solo `LIN_PROD` dentro de las 15 líneas configuradas se consulta a nivel SQL.
- Un error en un job se captura y registra sin detener el otro.
- HTTP 5xx/timeout Siemens usa backoff 2s, 4s, 8s, 16s y 32s, con máximo configurable de 60s; HTTP 4xx no se reintenta.

## PM2 en Windows

```powershell
npm install --production
npm run build
pm2 start ecosystem.config.js
pm2 save
```

El registro del servicio de Windows mediante `pm2-windows-startup` es responsabilidad del administrador de la PC y no se instala automáticamente por este proyecto.

## Verificaciones

```bash
npm run build
npx tsc --noEmit
npm test
npm run lint
```

No se requieren Firebird ni Siemens reales para iniciar la UI. Las pruebas de integración con sistemas reales pertenecen a UAT/Fase 3.
