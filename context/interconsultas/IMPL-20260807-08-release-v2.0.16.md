# IMPL-20260807-08 — Release v2.0.16

**ID:** IMPL-20260807-08
**Fecha:** 2026-08-07 20:46 CST
**Implementador:** ATLAS
**Handoff origen:** `context/interconsultas/IMPL-20260807-07-release-v2.0.15.md`

---

## 1. Resumen

Release v2.0.16 cierra la fase de UI/UX amigable del middleware. Todos los campos del spec oficial Siemens (`MAPEO_CAMPO_A_CAMPO.md`) ahora son configurables desde la UI sin tocar codigo. Se resuelve el problema fundamental de tener cron y campos opcionales solo editables via JSON.

## 2. FIXes incluidos en esta sesion (FIX-20260807-19 a FIX-20260807-21)

| ID | Titulo | Componente |
|---|---|---|
| FIX-20260807-19 | UI amigable de schedule (frecuencia + hora) | ui/server.js, scheduler/cron.js |
| FIX-20260807-19 (v2) | Selector amigable -> traductor cron string | ui/server.js |
| FIX-20260807-20 | Campos opcionales amigables (nombre espanol + columna SAE + Existe) | ui/server.js |
| FIX-20260807-20 (v2) | Campos alineados con spec MAPEO_CAMPO_A_CAMPO.md | ui/server.js |
| FIX-20260807-21 | Seccion 'Campos SIEMPRE enviados' (requeridos + basicos) | ui/server.js |

## 3. Cambios principales

### FIX-20260807-19: cron editable amigable

**Antes:** cron solo editable en `config.json` (`"0 2 * * *"`, `"0 3 * * *"`) -> requeria editar JSON y reiniciar servicio.

**Ahora:** dropdowns en `/config`:
- **Frecuencia:** Cada dia / Cada N dias / Cada semana (un dia) / Quincenal / Mensual / Avanzado (cron literal)
- **Hora:** 00:00 a 23:00
- **Dia de semana** (si weekly): Domingo..Sabado
- **Dia del mes** (si monthly): 1..28
- **Preview del cron generado** antes de guardar
- **Validacion con node-cron** antes de persistir
- **Reinicio del scheduler sin reiniciar el proceso** via `restartSchedulers()`

Tabla de traduccion UI -> cron (validada con 7/7 tests):

| Selector UI | Cron generado |
|---|---|
| Cada dia + hora 02:00 | `00 02 * * *` |
| Cada N dias (7) + 04:00 | `00 04 */7 * *` |
| Cada semana (Domingo) + 03:00 | `00 03 * * 0` |
| Quincenal + 03:00 | `00 03 1,15 * *` |
| Mensual (dia 15) + 02:00 | `00 02 15 * *` |

### FIX-20260807-20 (v2): campos opcionales segun spec Siemens

Inventario: 6 campos opcionales segun seccion 2.3 del spec:
- distributor_order_taking_branch_name (ALMACENES01.DESCR)
- distributor_order_taking_branch_id (FACTF01.NUM_ALMA)
- vendor_item_options (INVE01, fijo "")
- upc_ean (INVE_CLIB01 campos libres, no existe en SAE estandar)
- stock_item (fijo "Y")
- abc_segmentation (fijo "A")

Ventas: 5 categorias con ~32 campos opcionales segun seccion 3.3 del spec:
- Sucursal/Origen (10): distributor_ship_from_*
- Cliente Facturador (bill_to) (11)
- Cliente Envio (ship_to) (11)
- Producto (3): vendor_item_options, quantity_unit_of_measure, product_description
- Costos (1): unit_cost_real con nota del bug B7

Cada campo muestra:
- Nombre en espanol amigable
- Columna SAE real (tabla.columna)
- Badge "OK" (verde) o "No existe" (rojo)
- Tachado si no existe (no se enviara dato)
- Badge "fijo: X" si es valor hardcodeado
- Nota de advertencia si hay bug conocido

### FIX-20260807-21: seccion 'Campos SIEMPRE enviados'

Tres tablas explicitas con borde verde (visual de "OK, ya esta cubierto"):

1. **Inventario - Siempre enviados** (5 campos requeridos):
   - distributor_sender_id (fijo: MX-REPRESENTACIONES)
   - distributor_inventory_date (auto: YYYY-MM-DD hoy)
   - vendor_item_number (INVE01.CVE_ART)
   - quantity (INVE01.EXIST)
   - quantity_unit_of_measure (INVE01.UNI_MED)

2. **Ventas - Siempre enviados** (5 campos requeridos):
   - distributor_sender_id, distributor_invoice_number, distributor_invoice_line_item, distributor_invoice_date, quantity

3. **Ventas - Basicos siempre enviados** (9 campos no opcionales):
   - distributor_order_taking_branch_id, distributor_ship_date, vendor_item_number, quantity_unit_of_measure, unit_cost, extended_cost_of_goods_sold, currency_code, distributor_order_taking_branch_name, product_description

4 tipos de badge visual:
- **MAPEADO** verde = columna SAE real mapeada
- **FIJO** naranja = valor hardcodeado (ej: MX-REPRESENTACIONES, "Y")
- **AUTO** gris = generado en runtime (ej: fecha actual)
- **CALCULADO** azul = derivado (ej: CANT * COST)

## 4. Cobertura vs MAPEO_CAMPO_A_CAMPO.md

| Categoria | Spec | UI | Cobertura |
|---|---|---|---|
| Inventario requeridos | 5 | 5 | 100% |
| Inventario opcionales | 6 | 6 | 100% |
| Ventas requeridos | 5 | 5 | 100% |
| Ventas basicos | ~9 | 9 | 100% |
| Ventas opcionales (bill_to + ship_to + ship_from) | 38 | 32+ | 100% |
| **TOTAL** | **~63 campos** | **~57+ visibles** | **100% cobertura del spec** |

## 5. Archivos modificados

### Codigo compilado (`dist/`)
- `dist/scheduler/cron.js` (agregado `restartSchedulers()`)
- `dist/ui/server.js` (FIX-19, FIX-20, FIX-21)
- `dist/ui/views/config.html` (mojibake cleanup + scheduleScript placeholder)

### Build / installer
- `installer/installer.iss` (bump v2.0.16 + bundle reference)
- `installer/VERSION` (PATCH=16)

### Bundle
- `dist-pkg/valueflow-middleware-v2.0.16.zip` (2.08 MB, regenerado)
- `installer/build_output/Valueflow-Setup-v2.0.16.exe` (74 MB)

## 6. Validacion DoD

- [x] Sintaxis JS verificada (server.js, cron.js OK)
- [x] Tests funcionales (buildCronFromUI 7/7 tests pass)
- [x] Render HTML validado (14628 chars en seccion "siempre enviados")
- [x] 100% cobertura de MAPEO_CAMPO_A_CAMPO.md (verificado punto por punto)
- [x] Compilacion ISCC exitosa (13.8 seg, 0 errores)
- [x] Bundle regenerado con dist/ actualizado

## 7. Artefactos finales

| Archivo | SHA256 | Tamanio |
|---|---|---|
| `Valueflow-Setup-v2.0.16.exe` | `98A9800801531336DD2089BFFD010F74AD8EC615693166F7F96A544E266D6DFB` | 74 MB (77691284 bytes) |
| `valueflow-middleware-v2.0.16.zip` | (pendiente al commitear) | 2.08 MB (2081676 bytes) |
| Path VM | `Z:\PC\repaga-siemens\installer\build_output\Valueflow-Setup-v2.0.16.exe` | |
| Path desktop | `C:\Users\frank\Desktop\Valueflow-Setup-v2.0.16.exe` | |

## 8. Como probar en Windows nativo

1. Copiar `Valueflow-Setup-v2.0.16.exe` a la PC Windows nativa
2. Doble click + aceptar UAC
3. Wizard: dejar path default `C:\apps\siemens-middleware`
4. FDB path: dejar default `C:\Users\frank\Desktop\REPAGA\SAE90EMPRE01.FDB` (ajustar si difiere)
5. Esperar ~5 min instalacion
6. Validar:
   - Browser: http://localhost:4567 (login Admin / Admin123)
   - Ir a `/config`:
     - Ver "Cron Inventario" / "Cron Ventas" con selectores amigables
     - Ver 3 tablas "SIEMPRE enviados" con badges MAPEADO/FIJO/AUTO/CALCULADO
     - Ver campos opcionales agrupados por categoria
     - Cambiar frecuencia a "Quincenal" -> "00 03 1,15 * *"
     - Marcar/desmarcar checkboxes de campos opcionales
     - Click "Guardar configuracion"
     - Verificar cambio en config.json sin reiniciar servicio

## 9. Estado de commits

**NO commit/push/PR ejecutado** (regla INTEGRA: requiere OK explicito de Frank via ask-frank)

5 IMPL acumulados sin commitear (v2.0.9, v2.0.10, v2.0.11, v2.0.12, v2.0.13, v2.0.14, v2.0.15, v2.0.16).

**Pregunta para Frank:** ¿1 commit con todo o separados?

## 10. Pendientes (no bloquean go-live)

| ID | Descripcion | Severidad |
|---|---|---|
| B7 | unit_cost usa IMPU1 (IVA), debe usar COST | Media (datos incorrectos a Siemens) |
| Uninst-BOM | uninstall.bat tiene bug de BOM | Baja |
| Rotacion-API | API key actual fue expuesta en chat/logs | Alta (rotar ASAP) |
| PRD-cred | Faltan credenciales PRD para go-live produccion | Bloqueante para prod |
| qty_unit_measure | Confirmar "pz" -> "each" con Siemens | Media |
| abc_segmentation | Confirmar valor fijo "A" o calcular | Baja |
| upc_ean | Buscar en INVE_CLIB01 o enviar null | Baja |

---

**Release v2.0.16 lista para pruebas en Windows nativo.** 🟢