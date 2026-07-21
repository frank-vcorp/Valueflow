# Manual de operación — Middleware Repaga Siemens

## 1. Inicio y acceso

El servicio se ejecuta en la PC donde está instalado Aspel SAE 10. Con PM2 activo, abra `http://localhost:4567` e ingrese las credenciales definidas en `.env`. Todas las páginas y endpoints `/api/*` tienen autenticación Basic y la UI solo está ligada a localhost.

## 2. Dashboard

El Dashboard muestra por separado Inventario y Ventas: estado de la última ejecución, cantidad enviada y hora. El historial conserva las últimas 50 ejecuciones en memoria del proceso; los detalles operativos permanecen en logs JSON con rotación diaria de 90 días.

## 3. Configuración

En Configuración se pueden cambiar ambiente, URL base, `distributor_sender_id`, tamaño de batch, líneas Siemens y los toggles de cada job. Las líneas se almacenan en `config.json` y se aplican directamente a los filtros SQL en la siguiente consulta.

La API Key se cambia en el bloque protegido de la misma pantalla. Nunca se presenta completa: solo se muestran tres caracteres iniciales, tres finales y asteriscos. Al guardarla, la siguiente ejecución la lee desde `config.json` sin reiniciar el proceso.

## 4. Acciones manuales

- **Ejecutar Inventario ahora:** consulta el snapshot completo y envía batches.
- **Ejecutar Ventas ahora:** consulta el día anterior y envía únicamente líneas Siemens.
- **Test conexión Siemens:** valida respuesta HTTP del ambiente configurado.
- **Test conexión SAE:** ejecuta `SELECT 1 FROM RDB$DATABASE` con acceso de solo lectura.

No ejecute acciones manuales mientras el usuario esté modificando catálogos o cerrando facturación en SAE.

## 5. Jobs automáticos y errores

Inventario y ventas tienen cron, toggle, historial y `try/catch` independientes. Un 502/5xx de Siemens se reintenta con backoff exponencial. Un 4xx no se reintenta y requiere revisar esquema, ambiente o credenciales. Si Firebird no responde, el job afectado termina con error y el otro sigue disponible.

Una factura que no conserve ninguna línea cuyo `LIN_PROD` esté en la lista Siemens se omite completa; esto es normal y queda registrado a nivel debug.

## 6. Logs y diagnósticos

La página Logs lista archivos y permite descargar el archivo vigente. El formato es JSON, con rotación diaria y retención de 90 días. No se registran API Keys completas, contraseñas ni payloads de clientes completos. Diagnóstico muestra versión de Node, driver, rutas y valores sensibles enmascarados.

## 7. Mantenimiento Windows

Para actualizar: detenga el proceso PM2, respalde `config.json`, instale dependencias, compile y reinicie. Respaldar la carpeta `logs` y `config.json` según la política del cliente. No modifique la base de datos SAE desde el middleware.

## 8. Go-live pendiente

Antes de producción se deben confirmar credenciales PRD, `distributor_sender_id`, mapeo de unidad de medida, esquema exacto SAE 10, UAT y cinco días consecutivos de ejecuciones exitosas. Las pruebas contra Firebird real y Siemens QUA/PRD no están incluidas en el arranque local.
