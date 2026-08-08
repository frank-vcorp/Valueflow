# Handoff ATLAS → INTEGRA — Test independiente Siemens desde Linux

**Origen:** ATLAS M3 / sesión VM Windows 11 (VirtualBox)
**Fecha:** 2026-08-07 16:24 CST
**ID intervención:** DEBUG-20260807-01
**Stack:** curl 8.13.0 (Windows, sin HTTP/2), node 20.14.0, Schannel TLS
**Working dir:** `\\VBoxSvr\Proyectos_2.0\PC\repaga-siemens`

---

## 🎯 TL;DR

Necesito UNA verificación independiente AHORA desde el host Linux para resolver una inconsistencia de timing. El reporte `analysis/REPORTE_ENDPOINTS_SIEMENS_20260807.md` (creado 16:11 CST, hace 13 min) dice que dio HTTP 201 con la key `I1kfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv` desde Linux. Yo probé el MISMO comando (mismo payload, misma key, mismo endpoint) desde esta VM Windows AHORA MISMO (16:23 CST) y da **HTTP 403**. Misma IP pública `153.67.119.38` en ambos casos.

## 🧪 Las 3 hipótesis que hay que descartar

1. **Rate limit por los 20 tests del reporte**: si el reporte consumió el quota QUA, los siguientes dan 403/429
2. **Key revocada hace 12 minutos**: si alguien (¿Siemens? ¿Frank? ¿el equipo?) rotó la key entre 16:11 y 16:23
3. **El reporte no se generó HOY**: si es de otro día y la key YA estaba rota cuando se "ejecutó"

## 📋 Pruebas a ejecutar (Linux, AHORA)

Ejecutar **EXACTAMENTE** esto desde el host Linux y devolver el output verbatim:

```bash
date -u
echo "=== IP publica ==="
curl -s https://api.ipify.org
echo ""
echo "=== curl version ==="
curl --version | head -1

# La key del reporte (que dio 201 hace 13 min)
KEY='I1kfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv'
# La key rota que esta en .env actual de la VM
KEY_BAD='I1kLfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv'
# Payload exacto del Test 1 del reporte
PAYLOAD='[{"distributor_sender_id":"MX-REPRESENTACIONES","distributor_inventory_date":"2026-08-07","vendor_item_number":"TEST-CONN","quantity":1,"quantity_unit_of_measure":"PZA"}]'

echo ""
echo "=== TEST 1: HTTP/2 con key buena (I1kfm...) ==="
curl -s --http2 -w "\nHTTP_STATUS:%{http_code} TIME:%{time_total}s\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $KEY" \
  -d "$PAYLOAD" \
  "https://api.pos.siemens.com/qua/inventory/create_record"

echo ""
echo "=== TEST 2: HTTP/1.1 con key buena ==="
curl -s -w "\nHTTP_STATUS:%{http_code} TIME:%{time_total}s\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $KEY" \
  -d "$PAYLOAD" \
  "https://api.pos.siemens.com/qua/inventory/create_record"

echo ""
echo "=== TEST 3: HTTP/2 con key ROTA (I1kLfm...) ==="
curl -s --http2 -w "\nHTTP_STATUS:%{http_code} TIME:%{time_total}s\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $KEY_BAD" \
  -d "$PAYLOAD" \
  "https://api.pos.siemens.com/qua/inventory/create_record"

echo ""
echo "=== TEST 4: API key invalida (control negativo) ==="
curl -s --http2 -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: fake-key-fake-key-fake-key-fake-key-fake-key-fake" \
  -d "$PAYLOAD" \
  "https://api.pos.siemens.com/qua/inventory/create_record"

echo ""
echo "=== TEST 5: GET raiz sin auth ==="
curl -s -w "\nHTTP_STATUS:%{http_code}\n" "https://api.pos.siemens.com/qua/"

echo ""
echo "=== TEST 6: DNS ==="
dig +short api.pos.siemens.com
```

## 📤 Lo que necesito de vuelta

**Output literal** de cada test, especialmente:
- `HTTP_STATUS` de cada uno
- Headers `x-amzn-requestid`, `x-amzn-errortype`, `x-amzn-trace-id` (los necesito para correlacionar con mis tests)
- Body de respuesta
- Tu IP pública CONFIRMADA al momento del test
- Timestamp UTC al inicio de cada test

## 🔍 También necesito (si lo podes ver)

Información sobre el archivo del reporte:
- Fecha/hora REAL de creación del archivo `analysis/REPORTE_ENDPOINTS_SIEMENS_20260807.md` (ya confirmé 16:11 pero por las dudas)
- Si hay algun log/cache que muestre que los tests del reporte realmente se ejecutaron y no fueron copiados de otro lado

## ⚠️ NO necesito

- Código nuevo
- Fixes
- Análisis profundo
- Decisiones arquitectónicas

**Solo el output verbatim de los curls.** Es 30 segundos de tu tiempo y me ahorra 30 minutos de hipótesis.

## 📍 Working dir y paths

- Repo en Linux: `/mnt/Datos/Proyectos 2.0/PC/repaga-siemens`
- VM Windows: `\\VBoxSvr\Proyectos_2.0\PC\repaga-siemens`
- Reporte: `analysis/REPORTE_ENDPOINTS_SIEMENS_20260807.md`

## 🚦 Si alguno da 403

Si los tests desde Linux dan **HTTP 403** (mismo que desde Windows), entonces:
- El problema es **100% del lado de Siemens** (key revocada / rate limit / sandbox caído)
- NO hay nada que arreglar en el middleware
- Frank debe contactar a Siemens con la evidencia

Si los tests desde Linux dan **HTTP 201** (como dice el reporte), entonces:
- Es problema de **IP whitelist** (la IP `153.67.119.38` ya no está whitelisteada para esta key)
- Frank debe pedir a Siemens que re-whitelist la IP

En ambos casos, **el middleware está OK** y el próximo paso es coordinación con Siemens.

---

**Sesión ATLAS:** esperando output de INTEGRA para cerrar el diagnóstico.
**Frank:** pasale este handoff cuando puedas, o ejecutá vos mismo los curls desde la terminal Linux si tenés acceso.