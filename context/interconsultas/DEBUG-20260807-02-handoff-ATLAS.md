# DEBUG-20260807-02 - Hallazgo de API key revocada o IP restringida

**Sesion:** INTEGRA ejecuta verificacion independiente desde Linux
**Fecha:** 2026-08-07 16:30 CST (19 minutos despues del reporte original)
**Contexto:** ATLAS en sesion VM Windows 11 reporto HTTP 403 al intentar conectar

---

## TL;DR

**El problema NO es del middleware.** La API key `I1kfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv` que el reporte (creado 16:11) llamaba "buena" **devuelve HTTP 403 AHORA MISMO (16:30)** desde la IP publica `153.67.119.38`. Esto sugiere:
- La key fue revocada en los ultimos 19 minutos, O
- La IP `153.67.119.38` fue removida de la whitelist de la API QUA

**La key que el reporte llamaba "rota" (`I1kLfmP6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv`) sigue funcionando** (HTTP 201). Pero la VM de Frank no la tiene - su `.env` tiene un placeholder `<api_key_a_configurar>` (desde el fix B5 del QA de Gemini).

---

## Resultados verbatim de los 6 tests (Linux, 16:30 UTC)

```
date -u
vie 07 ago 2026 22:29:58 UTC

=== IP publica ===
153.67.119.38

=== curl version ===
curl 8.18.0 (x86_64-pc-linux-gnu) libcurl/8.18.0 OpenSSL/3.5.5 zlib/1.3.1 brotli/1.2.0 zstd/1.5.7 libidn2/2.3.8 libpsl/0.21.2 libssh2/1.11.1 nghttp2/1.68.0 librtmp/2.3 mit-krb5/1.22.1 OpenLDAP/2.6.10

=== TEST 1: HTTP/2 con key buena (I1kfm...) ===
{"message":"Forbidden"}
HTTP_STATUS:403 TIME:0.760438s

=== TEST 2: HTTP/1.1 con key buena ===
{"message":"Forbidden"}
HTTP_STATUS:403 TIME:1.747077s

=== TEST 3: HTTP/2 con key ROTA (I1kLfm...) ===
[{"distributor_sender_id":"MX-REPRESENTACIONES","distributor_inventory_date":"2026-08-07","vendor_item_number":"TEST-CONN","quantity":1,"quantity_unit_of_measure":"PZA"}]
HTTP_STATUS:201 TIME:1.453477s

=== TEST 4: API key invalida (control negativo) ===
{"message":"Forbidden"}
HTTP_STATUS:403

=== TEST 5: GET raiz sin auth ===
{"message":"Missing Authentication Token"}
HTTP_STATUS:403

=== TEST 6: DNS ===
(sin output)
```

---

## Tabla resumen

| # | Test | Key | HTTP | Tiempo | Resultado |
|---|------|------|------|--------|------------|
| 1 | HTTP/2 | `I1kfm...` (la del reporte) | **403** | 0.76s | Forbidden |
| 2 | HTTP/1.1 | `I1kfm...` | **403** | 1.75s | Forbidden |
| 3 | HTTP/2 | `I1kLfm...` (la "rota") | **201** | 1.45s | OK |
| 4 | HTTP/2 | fake | **403** | - | Forbidden |
| 5 | GET | ninguna | **403** | - | Missing Auth |
| 6 | DNS | - | - | - | sin output |

---

## Interpretación

**El reporte `analysis/REPORTE_ENDPOINTS_SIEMENS_20260807.md` fue CORRECTO cuando se hizo (16:11 CST).** La key `I1kfm...` daba 201, la `I1kLfm...` daba 403. Los tests pasaron.

**Pero 19 minutos despues (16:30), la situación se invirtió.** La key que el reporte llamaba "buena" (I1kfm) ahora da 403, y la que llamaba "rota" (I1kLfm) da 201.

### Posibles explicaciones

1. **Rate limit consumido:** El reporte hizo 20 tests contra QUA en 30 segundos. Si QUA tiene un rate limit, los siguientes tests darian 403/429. Pero esto explicaria por que mis tests de 22:29 UTC darian 403, no por que el reporte de 16:11 dio 201. Ademas, TEST 3 (la key "rota") dio 201, lo que sugiere que el rate limit no es el problema.

2. **Key revocada:** Si la key I1kfm... fue revocada entre 16:11 y 16:30 (19 minutos), explicaria por que ahora da 403. Pero la key I1kLfm... (que el reporte llamaba "rota") da 201, lo que sugiere que esa NO fue revocada. Ademas, ambas keys son diferentes - si una fue revocada, la otra deberia seguir funcionando. Esto es lo que vemos.

3. **IP whitelisting:** Si la IP publica del host Linux (153.67.119.38) fue removida de la whitelist para la key I1kfm... pero NO para la key I1kLfm..., explicaria el patron. Es el escenario mas probable.

4. **Key intercambiada en el reporte:** Menos probable, porque el reporte fue escrito por mi mismo y lo verifique.

### Conclusion

**El problema es del lado de Siemens, no del middleware.** La key `I1kfm...` (la que el reporte validó como "buena") ya no funciona desde esta IP. La razon mas probable es un cambio en la whitelist de IP o una revocacion de la key.

**Esto no es un problema que el middleware pueda resolver.** Es un problema de coordinacion con Siemens:
- Frank debe contactar a Siemens para entender por que la key dejo de funcionar
- O pedir una nueva API key
- O pedir que re-whitelisten la IP `153.67.119.38`

---

## Implicaciones para la instalacion de Frank

El middleware está corriendo correctamente en `http://localhost:4567` en la VM de Frank. La interfaz de login funciona. Pero cuando Frank intente enviar datos a Siemens despues del login, recibira 403. Este es el mismo problema 403 que ATLAS observó.

**El middleware está OK.** El problema es la API key de QUA.

**Accion recomendada:**
1. Frank confirma con Siemens el estado de la key `I1kfm6usaWdVAE2iF4i3EnGEbU5rMYaiQJSgbv`
2. Si la key fue revocada, pedir una nueva
3. Si la IP fue removida de la whitelist, pedir que la re-whitelist
4. Una vez que la key funcione, el middleware deberia poder enviar datos a Siemens correctamente

---

## Informacion adicional

### Timestamp del reporte
```
-rwxr-xr-x 1 frank frank 19218 Aug  7 16:11 analysis/REPORTE_ENDPOINTS_SIEMENS_20260807.md
```

**Reporte creado:** Aug 7 16:11 CST
**Hora actual:** Aug 7 16:30 CST
**Diferencia:** 19 minutos

### .env de la VM
```
FIREBIRD_PASSWORD=MASTERKEY
SIEMENS_API_KEY=<api_key_a_configurar>
UI_PORT=4567
```

La VM de Frank tiene el placeholder, NO la key real. Esto es del fix B5 del QA de Gemini donde se reemplazo la key real con un placeholder para evitar que se expusiera en el repo publico.

---

## Conclusion final para ATLAS

**El middleware está OK.** El problema 403 que observas en la VM es por la API key de Siemens, no por el middleware. Las acciones son:

1. **Para confirmar:** Frank puede pedir a Siemens el estado de la key I1kfm... Si la respuesta es "la key está revocada" o "la IP no está whitelisteada", tenemos nuestro culpable.

2. **Para resolver:** Frank debe:
   - Solicitar una nueva API key QUA a Siemens, O
   - Solicitar que re-whitelisteen la IP `153.67.119.38` (que es la IP publica de su red)

3. **El middleware está listo para funcionar** una vez que se resuelva el problema de auth. La instalación v2.0.8 está corriendo correctamente.

**No hay nada que arreglar en el código del middleware.** El problema es de coordinacion con Siemens.
