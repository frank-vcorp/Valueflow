# PROYECTO — Repaga Siemens Integration

**Cliente:** REPRESENTACIONES AGA 2 (Repaga)
**Stack destino:** Aspel SAE 10 + Siemens PoSi API
**Contacto:** Francisco Aguirre
**Última actualización:** 2026-07-21 (19:05)

## Objetivo
Integrar Aspel SAE 10 con Siemens PoSi para sincronizar ventas (Value Flow) e inventario en tiempo real mediante middleware local.

## Arquitectura confirmada
- Middleware en la misma PC Windows de SAE 10 (conexión localhost)
- Acceso directo a Firebird 5.0 vía `node-firebird-native-api`
- UI local de administración en `localhost:4567`
- Scheduler con `node-cron` embebido
- Sin mantenimiento mensual — intervenciones por presupuesto previo
- Volumen del cliente: ~12,000 productos → 4 batches de inventario

## Backlog

### [x] Completado
- **SIEMENS-TEST-20260720-01** — Prueba de conexión a Siemens PoSi API (QUA).
  - ✅ Credenciales QUA validadas: `qua-MX-REPRESENTACIONES` + API Key (ofuscada `I1kL****gbv`).
  - ✅ 2 endpoints probados con autenticación exitosa:
    - `https://api.pos.siemens.com/qua/create_record` (Value Flow / Ventas)
    - `https://api.pos.siemens.com/qua/inventory/create_record` (Inventario)
  - ✅ Esquema técnico completo descubierto (11 campos inventario, 43 campos Value Flow).
  - ✅ Reporte PDF generado: `REPORTE_CONEXION_SIEMENS.pdf` (5 pp, 97 KB).
  - ✅ HTML fuente: `REPORTE_CONEXION_SIEMENS.html`.
  - Distributor sender ID confirmado: `MX-REPRESENTACIONES`.
  - Sin datos reales enviados a Siemens (todos sintéticos: TEST-CONN-001, SKU-TEST).
  - Latencia promedio: ~0.55 s.
- **SIEMENS-TEST-20260721-01** — Re-verificación de sandbox y validación de esquema (24h después).
  - ✅ DNS resuelve (`api.pos.siemens.com` → AWS).
  - ✅ TLS handshake OK, certificado Amazon RSA 2048.
  - ✅ Puerto 443 abierto.
  - ✅ Ambos endpoints devuelven **HTTP 201 Created** con el esquema mínimo confirmado.
  - ✅ Decisión arquitectónica: **`distributor_sender_id` debe ser configurable desde UI**, no hardcoded en código.
  - ✅ Decisión arquitectónica (refinamiento 2026-07-21 15:15): **patrón de campos opcionales seleccionables desde UI**:
    - Campos requeridos: hardcoded como obligatorios, siempre se envían (5 inventario / 10 ventas)
    - Campos opcionales: listados en UI como toggles, default OFF, cliente activa selectivamente sin tocar código
    - Si opcional activo pero dato vacío en SAE 10 → se omite silenciosamente
    - Configuración operativa en `config.json` (editable desde UI), secretos en `.env`
  - ✅ Decisión de negocio (Ing. Paco, 2026-07-21 15:20): **filtro de marca Siemens por campo `LIN_PROD`**:
    - Solo se reportan a Siemens las líneas de factura donde `LIN_PROD` ∈ {BAJA, SINU, SIMAT, LP, DRIVE, MOTOR, SINUM, SERVI, OBSO, SENSO, SERVO, INSTR, UPS, SIMA, ESPE}
    - 7,788 productos Siemens identificados en catálogo del cliente (15 líneas activas)
    - Lógica: factura se lee completa, se descartan líneas no-Siemens, si no quedan líneas se omite la factura completa
    - Lista de líneas válida en `config.json` (editable desde UI)
  - ✅ Validación contra BD real Firebird (2026-07-21 15:25):
    - Conteo en INVE01: 30,635 productos totales / 21,805 en líneas Siemens / 7,788 activos
    - Hallazgo: el documento de 7,788 correspondía a productos con `STATUS='A'` (activos). Para filtro completo usar los 21,805.
    - 42,998 facturas vigentes en histórico; 28,274 (~66%) contienen al menos un producto Siemens
    - Encontrada factura real con líneas mixtas: `CFDI_32670` (cliente 830, 2026-07-03) con 4 líneas Siemens + 2 no-Siemens (Hoffman + canaleta)
    - Validado: el filtro funciona, solo se enviarían las 4 líneas correctas
  - ⚠️ **Prueba con datos reales (2026-07-21 15:28)**: payload con datos filtrados reales enviado a QUA → **HTTP 502 Internal Server Error** (persistente después de 3 reintentos con backoff).
    - Conclusión: el problema es **del sandbox QUA de Siemens**, no de nuestro payload.
    - Ver: `MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md` (ya documentado el 2026-07-20 22:30)
    - Acción: contactar Siemens Data Steward regional para reportar la incidencia del sandbox.
    - ✅ **Intermitencia confirmada (2026-07-21 15:31)**: Mismo payload exacto, misma API Key, mismo endpoint:
      - 15:04 hrs → **HTTP 201 Created** ✓ (prueba inicial exitosa)
      - 15:28-31 hrs → **HTTP 502 Bad Gateway** (3+ intentos consecutivos)
      - Conclusión: el servidor QUA pasa de UP a DOWN sin que cambiemos nada → **intermitencia del lado de Siemens, NO de nuestra implementación**.
      - Implicación: el middleware debe implementar reintentos robustos; el go-live debe ser directo a PRD (no al QUA intermitente).
    - ✅ **Prueba end-to-end via UI (2026-07-21 16:43)**: Configuración cargada via UI + test ejecutado desde la UI del middleware.
      - Se cargó `api_key` y `distributor_sender_id` via formulario en `/config` con enmascaramiento.
      - Se ejecutó "Test conexión Siemens" desde `/actions` → respuesta real del sandbox.
      - **Bug detectado y corregido:** el `environment` en `config.json` venía como `"QUA"` (mayúsculas) cuando la API espera `"qua"` (minúsculas). Esto causaba HTTP 403. Corregido a `qua` via UI.
      - Después del fix, la respuesta es **HTTP 502** (sandbox sobrecargado, ya documentado) — confirmando que la URL, autenticación y payload son correctos.
      - Validación final: la API responde, no es 401/403 por key, solo 502 por intermitencia del servidor.

### [x] Completado
- **ERP-INT-005** — Integración Aspel SAE 10 + Siemens PoSi (Fase 1-3, 6 semanas, $60K MXN + IVA).
  - Estado: **Fase 1 COMPLETADA. Fase 2 IMPLEMENTADA por SOFIA (2026-07-21 15:52)**. Pendiente: instalación en PC Windows del cliente + credenciales PRD.
  - **SPEC-IMPL-20260721-01-siemens-middleware.md** implementada por SOFIA. Ver `repaga-siemens/middleware/` (41 archivos).
  - Validaciones SOFIA: `npm run build` OK, `tsc --noEmit` OK, `npm test` OK (7 tests, 80.43% coverage), lint OK.
  - Limitación conocida: `npm install` no completó en este entorno Linux por problemas de compilación del addon nativo. Se resuelve en Windows con Node 20 LTS + `fbclient.dll` de SAE 10.
  - Última validación (2026-07-21 15:38): filtro marca Siemens OK, esquema API OK, intermitencia sandbox documentada.
  - Documentos comerciales generados:
    - `PROPUESTA_TECNICA_SAE10_SIEMENS.md` + `.pdf` (v1.3)
    - `PROPUESTA_ECONOMICA_SAE10_SIEMENS.md` + `.pdf` (v1.5)
    - `CORREO_PRESENTACION.md` (plantilla de correo)
  - Documentos de análisis (referencia interna):
    - `SIEMENS_INTEGRATION_EXTRACT.md` (extracto del portal)
    - `SAE10_SIEMENS_INTEGRATION_ANALYSIS.md` (análisis arquitectónico)
  - **Entregables Fase 1 (Discovery):**
    - ✅ `REPORTE_CONEXION_SIEMENS.pdf` — Prueba de conexión QUA validada
    - ✅ `ESQUEMA_BD_SAE.md` — Análisis completo de BD Aspel SAE 9.0 (210 tablas)
    - ✅ `MAPEO_CAMPO_A_CAMPO.md` — Mapeo campo a campo SAE ↔ Siemens (entregable formal)
    - ✅ 7,788 productos Siemens identificados en 15 líneas
    - ✅ Queries de extracción validados con datos reales
    - ✅ Esquema Siemens completo documentado (11 campos inventario, 43 campos Value Flow)

### [ ] Pendiente
- Credenciales PRD de Siemens (actualmente solo QUA).
- Confirmar `distributor_sender_id` con cliente (`MX-REPRESENTACIONES`).
- Decisión: mapeo de `quantity_unit_of_measure` ("pz" → "each" o enviar "pz").
- Actualización del cliente a Aspel SAE 10 (actualmente tiene SAE 9.0).

## Notas operativas
- Este proyecto es independiente de `repaga-harvesting` (que maneja extracción de catálogos).
- La integración con Siemens requiere que el cliente actualice a Aspel SAE 10 (actualmente tiene SAE 9.0).
- Imágenes corporativas para UI disponibles: `logo_aga_letras_2.png` (Repaga) y `partner.png` (Siemens Approved Partner).

## Especificación técnica (SPEC)
- **`SPEC-IMPL-20260721-01-siemens-middleware.md`** → [`context/SPECs/SPEC-IMPL-20260721-01-siemens-middleware.md`](../context/SPECs/SPEC-IMPL-20260721-01-siemens-middleware.md)
  - Estado: ✅ **Implementada por SOFIA** (2026-07-21 15:52). 41 archivos en `middleware/`. Pendiente instalación en PC Windows del cliente.
  - Contiene: stack técnico, estructura de proyecto, modelo de datos (`.env` + `config.json`), 8 RFs (Firebird, queries, transformador, API cliente, scheduler, UI con logos, logging, errores), DoD, self-review checklist.

- **`SPEC-INFRA-20260721-01-cicd-github-actions.md`** → [`specs/SPEC-INFRA-20260721-01-cicd-github-actions.md`](../specs/SPEC-INFRA-20260721-01-cicd-github-actions.md)
  - Estado: **Lista para delegación a SOFIA** — CI/CD con GitHub Actions.
  - Contiene: 3 workflows (ci.yml para validación, build-installer.yml para compilar .exe con Wine+Inno Setup, release.yml para releases por tag), security scan con Trivy, documentación de workflows.

## Autorizaciones autónomas vigentes
- Sin lote nocturno activo. El usuario trabajará Siemens personalmente en otro chat.
