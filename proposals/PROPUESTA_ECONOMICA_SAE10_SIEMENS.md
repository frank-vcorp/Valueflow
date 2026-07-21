# PROPUESTA ECONÓMICA

## Integración Aspel SAE 10 ↔ Siemens PoSi Portal

**ID Documento:** ARCH-20260706-03  
**Fecha:** 2026-07-06 
**Preparado por:** Ing. Frank Saavedra|Vcorp
**Documento técnico asociado:** [PROPUESTA_TECNICA_SAE10_SIEMENS.md](./PROPUESTA_TECNICA_SAE10_SIEMENS.md) (ARCH-20260706-02)

---

### Datos del Cliente

| Campo                | Valor                            |
| -------------------- | -------------------------------- |
| **Cliente**          | Representaciones Aga de Saltillo |
| **Contacto técnico** | Ing. Francisco Aguirre           |
| **Email**            | fcoaguirre@repaga.com.mx         |
| **Teléfono**         | 844 160 6737                     |

---

## 1. RESUMEN DE INVERSIÓN

| Concepto                                                                       | Importe                                     |
| ------------------------------------------------------------------------------ | ------------------------------------------- |
| **Implementación llave en mano** (Fases 1 a 3)                                 | **$60,000 MXN + IVA**                       |
| **Intervenciones post go-live** (solo si se requieren, con presupuesto previo) | Ver sección 3                               |
| **Validez de la propuesta**                                                    | 30 días naturales desde la fecha de emisión |

**Política comercial:** Esta propuesta **NO incluye contratos recurrentes** (mensualidades, bolsas de horas, suscripciones). Cualquier intervención técnica posterior al go-live se cotiza por separado y se ejecuta solo con aprobación previa por escrito del cliente.

---

## 2. INVERSIÓN POR FASES

### Fase 1 — Discovery & Credenciales

**Objetivo:** Obtener credenciales de Siemens (vía solicitud directa al portal), analizar BD SAE 10 y generar documento de mapeo campo a campo.

| Actividad                                                               | Horas humano    |
| ----------------------------------------------------------------------- | --------------- |
| Solicitud de API Keys, plantillas y credenciales SFTP al portal Siemens | 1               |
| Análisis del modelo de datos de SAE 10 (Firebird 5.0)                   | 3               |
| Mapeo campo a campo SAE 10 ↔ Siemens                                    | 4               |
| Documento de mapeo aprobado por cliente                                 | 2               |
| **Subtotal Fase 1**                                                     | **10 h humano** |

**Entregable de Fase 1:**

- Documento de mapeo campo a campo (`.xlsx` + `.pdf`)
- Confirmación de credenciales recibidas de Siemens

### Fase 2 — Desarrollo del Middleware

**Objetivo:** Construir el middleware de integración Node.js con acceso a Firebird 5.0 y envío a Siemens.

| Actividad                                            | Horas humano    |
| ---------------------------------------------------- | --------------- |
| Configuración del proyecto + conexión a SAE 10       | 2               |
| Desarrollo e implementación del módulo de Inventario | 2               |
| Desarrollo e implementación del módulo de Ventas     | 3               |
| Revisión del transformador JSON/CSV                  | 2               |
| Revisión del cliente API/SFTP Siemens                | 2               |
| Validación y ajustes finales                         | 2               |
| **Subtotal Fase 2**                                  | **13 h humano** |

**Entregable de Fase 2:**

- Código fuente del middleware (repositorio Git)
- Binarios funcionales
- Pruebas unitarias básicas

### Fase 3 — Pruebas & Go-Live

**Objetivo:** Validar el sistema en QAS de Siemens, ejecutar UAT con el cliente y poner en producción.

| Actividad                                                 | Horas humano    |
| --------------------------------------------------------- | --------------- |
| Pruebas en ambiente QAS de Siemens                        | 3               |
| UAT con usuario final del cliente                         | 3               |
| Despliegue a producción + configuración PM2 como Servicio | 2               |
| Monitoreo intensivo primera semana                        | 2               |
| Documentación técnica + manual de operación               | 2               |
| **Subtotal Fase 3**                                       | **12 h humano** |

**Entregable de Fase 3:**

- Manual técnico (`.pdf`)
- Manual de operación y troubleshooting
- Acta de aceptación de UAT firmada

### Total Implementación

| Fase                       | Horas humano | Importe     |
| -------------------------- | ------------ | ----------- |
| Fase 1 — Discovery         | 10 h         | $17,000     |
| Fase 2 — Desarrollo        | 14 h         | $25,000     |
| Fase 3 — Pruebas & Go-Live | 12 h         | $18,000     |
| **TOTAL IMPLEMENTACIÓN**   | **36 h**     | **$60,000** |
|                            |              | **+ IVA**   |

---

## 3. SOPORTE POST GO-LIVE: INTERVENCIONES POR PRESUPUESTO

**Regla general:** Cualquier intervención técnica solicitada **después de las pruebas go-live** genera un **costo previamente pactado** entre el cliente y el proveedor. No hay mantenimiento mensual, no hay bolsas de horas, no hay suscripciones.

### 3.1 ¿Qué cuenta como intervención?

Cualquier trabajo técnico solicitado por el cliente que ocurra después de la firma del acta de go-live exitoso, incluyendo pero no limitado a:

- API Key de Siemens expirada y requiere reconfiguración
- Cambio de esquema en SAE 10 que rompe una query existente
- Error recurrente en una ejecución específica
- Actualización de Windows rompió el servicio PM2
- Necesidad de ajustar frecuencia, horarios o ambiente (QAS/PRD)
- Nuevas funcionalidades, integraciones adicionales o adaptaciones
- Migración del servidor o del PC de SAE 10
- Cualquier otro trabajo técnico que requiera acceso al código o configuración del middleware

### 3.2 Proceso de intervención (5 pasos)

```
1. Cliente reporta incidencia o solicita cambio
   ↓
2. Proveedor evalúa alcance (gratuito, sin compromiso)
   ↓
3. Proveedor envía cotización por escrito
   (incluye: horas estimadas, tarifa, plazo de entrega, riesgos)
   ↓
4. Cliente aprueba cotización por escrito
   (correo electrónico es suficiente)
   ↓
5. Proveedor ejecuta trabajo → emite factura
```

### 3.3 Tarifas aplicables a intervenciones

| Concepto                                          | Detalle                                              |
| ------------------------------------------------- | ---------------------------------------------------- |
| **Tarifa preferencial cliente de implementación** | **$1,500 MXN + IVA / hora**                          |
| **Tarifa estándar cliente nuevo**                 | $1,800 MXN + IVA / hora                              |
| **Mínimo facturable por intervención**            | 2 horas                                              |
| **Forma de facturación**                          | Una sola factura al cierre de la intervención        |
| **Medio de pago**                                 | Transferencia o SPEI a 5 días naturales post-factura |
| **Moneda**                                        | Pesos Mexicanos (MXN)                                |

> ⚠️ **Importante:** Si el proveedor detecta que el alcance real supera el presupuesto aprobado, **debe informarlo de inmediato** y solicitar aprobación adicional antes de continuar. Ningún trabajo se factura por encima de lo aprobado sin consentimiento escrito previo.

### 3.4 Tiempos de respuesta para envío de cotización

| Tipo de solicitud                                          | Tiempo para enviar cotización |
| ---------------------------------------------------------- | ----------------------------- |
| **Crítica** (middleware caído, no se envía info a Siemens) | **4 horas hábiles**           |
| **Normal** (error recurrente, ajuste menor)                | **24 horas hábiles**          |
| **Programada** (cambio planificado, mejora)                | **3 días hábiles**            |

### 3.5 Horario de atención para reporte de incidencias

- Lunes a viernes, 9:00 a 18:00 hrs (tiempo del centro)
- Canal: correo electrónico a **frank@vcorp.mx** y/o WhatsApp al 4421717886

### 3.6 Garantía post go-live (incluida en los $60,000)

Antes de que aplique cualquier costo de intervención, existe un periodo de garantía cubierto por la inversión inicial:

| Concepto                 | Detalle                                                                                                               |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| **Vigencia de garantía** | **15 días naturales** posteriores al go-live exitoso                                                                  |
| **Cubre**                | Defectos de implementación, errores del código entregado, configuración incorrecta                                    |
| **No cubre**             | Cambios solicitados por el cliente, actualizaciones externas (Siemens/SAE 10), nuevos requisitos, errores por mal uso |
| **Costo**                | Incluido en los $60,000 (sin cargo extra)                                                                             |
| **Proceso**              | Se reporta igual que cualquier intervención (sección 3.2) pero **sin cotización** — es garantía                       |

Una vez vencidos los 15 días, **toda intervención técnica** se rige por las reglas de esta sección.

---

## 4. CONDICIONES COMERCIALES

### 4.1 Forma de pago (Implementación)

| Hito de pago    | Porcentaje | Importe       | Momento                                                      |
| --------------- | ---------- | ------------- | ------------------------------------------------------------ |
| Anticipo        | **30%**    | $18,000 + IVA | A la aprobación de la propuesta                              |
| Entrega Fase 2  | **40%**    | $24,000 + IVA | Al completar middleware funcional                            |
| Go-Live exitoso | **30%**    | $18,000 + IVA | Tras 5 días consecutivos de operación correcta en producción |

### 4.2 Forma de pago (Intervenciones post go-live)

- Cotización enviada y aprobada por escrito antes de iniciar cualquier trabajo
- Factura emitida al cierre de la intervención aprobada
- Pago a 5 días naturales post-factura vía transferencia o SPEI

### 4.3 Moneda y facturación

- **Moneda:** Pesos Mexicanos (MXN)
- **IVA:** 16% adicional, desglosado en factura
- **CFDI:** Emitido al día de la facturación

### 4.4 Datos de facturación del cliente

- RFC de Representaciones Aga de Saltillo: [A CONFIRMAR]
- Domicilio fiscal: [A CONFIRMAR]
- Email para envío de CFDI: [A CONFIRMAR]

### 4.5 Tarifa horaria para trabajos fuera del alcance

- **Tarifa estándar:** $1,800 MXN + IVA / hora
- **Tarifa preferencial post go-live (cliente de implementación):** $1,500 MXN + IVA / hora
- Trabajos fuera del alcance requieren **autorización previa por escrito** antes de iniciar
- Cualquier tiempo extra se reporta semanalmente con detalle

---

## 5. QUÉ INCLUYE LA INVERSIÓN

### ✅ Incluido en los $60,000

- 36 horas de trabajo humano especializado (arquitecto + revisor)
- Construcción del middleware con metodología ágil y entregas iterativas
- Acceso al código fuente del middleware (repositorio Git)
- Manual técnico + manual de operación
- Configuración inicial del entorno (PM2, Node.js, UI local)
- Soporte durante go-live (1ra semana intensiva)
- **15 días de garantía** después del go-live para defectos de implementación

### ❌ NO incluido

- Licencias de software adicionales (Node.js es open source)
- Costo de licencias Siemens (gestión directa entre cliente y Siemens)
- Infraestructura cloud o servidores adicionales
- Modificaciones al esquema de SAE 10
- Migración de Firebird a SQL Server (si llegara a requerirse)
- Capacitación presencial a más de 3 personas del cliente
- **Cualquier intervención técnica post go-live** (se cotiza por separado bajo el modelo de presupuesto previo de la sección 3)
- Trabajo fuera del alcance definido en esta propuesta (se cotiza por separado)

---

## 6. CRONOGRAMA ESTIMADO

| Fase                                   | Duración      | Calendario  |
| -------------------------------------- | ------------- | ----------- |
| **Fase 1** — Discovery & Credenciales  | **1 semana**  | Semana 1    |
| **Fase 2** — Desarrollo del Middleware | **3 semanas** | Semanas 2-4 |
| **Fase 3** — Pruebas & Go-Live         | **2 semanas** | Semanas 5-6 |
| **Total implementación**               | **6 semanas** | Semanas 1-6 |

**Notas importantes del cronograma:**

- La **Fase 1 inicia** una vez aprobada la propuesta Y recibidas las credenciales de Siemens (la solicitud se hace al portal en cuanto el cliente confirme la aprobación).
- Se requiere acceso al PC Windows de SAE 10 **desde la primera semana** para poder validar conexión y esquema de Firebird 5.0.
- Las 6 semanas consideran el modelo de ejecución optimizado del proveedor. Cualquier retraso atribuible a terceros (Siemens, cliente) ajusta el calendario sin penalización.

### Consideración especial: volumen del cliente

El cliente maneja aproximadamente **12,000 productos** en su catálogo. Esto implica que:

- Para el flujo de **Inventario** (snapshot completo): se requieren **4 batches de ~3,000 registros cada uno** para cumplir con el límite de 3,000 transacciones por batch que recomienda Siemens.
- El middleware implementará **particionamiento automático** para dividir el envío y mantener trazabilidad por lote.
- El proceso de envío completo (4 batches) toma entre **5 y 10 minutos** dependiendo de la latencia de red hacia Siemens.
- Para el flujo de **Ventas** (filtrado por día), el volumen típico es mucho menor (decenas a centenas de facturas), por lo que un solo batch es suficiente.

---

## 7. SUPUESTOS ECONÓMICOS

- El cliente proporcionará **acceso a un usuario de BD con permisos de solo lectura** sobre las tablas necesarias de SAE 10 sin costo adicional.
- El cliente gestionará **directamente con Siemens** la solicitud de API Keys, plantillas y credenciales SFTP. Los tiempos de respuesta de Siemens no dependen de nosotros.
- Las 36 horas humanas son **a todo costo**: incluyen arquitectura, desarrollo, pruebas, comunicación con el cliente, redacción de documentos y seguimiento.
- La tarifa ofrecida refleja la eficiencia operativa del proveedor y permite mantener precios competitivos sin sacrificar calidad profesional.
- Cualquier **trabajo fuera del alcance** definido en la propuesta técnica será cotizado por separado previa aprobación.
- El cliente tiene **derecho de auditar** el código fuente y los entregables en cualquier momento durante el proyecto.

---

## 8. RIESGOS QUE PUEDEN AFECTAR EL CRONOGRAMA O COSTO

| Riesgo                                                         | Impacto en costo      | Mitigación                                                     |
| -------------------------------------------------------------- | --------------------- | -------------------------------------------------------------- |
| Cambios en el esquema de Siemens durante el proyecto           | + horas               | Monitoreo continuo; alerta temprana                            |
| Retraso en entrega de credenciales por Siemens                 | Retrasa inicio Fase 2 | Solicitar credenciales inmediatamente tras aprobación          |
| Esquema de SAE 10 muy diferente al esperado                    | + 4-6 horas humano    | Discovery profundo con queries al catálogo Firebird            |
| Incremento significativo de volumen (>5000 registros/batch)    | + horas optimización  | Particionamiento y validación temprana                         |
| Cliente solicita funcionalidades adicionales fuera del alcance | Cotización separada   | Acta de cambio firmada antes de ejecutar                       |
| Imprevistos técnicos durante la integración                    | Retraso en entrega    | Buffer de horas humano + comunicación proactiva con el cliente |

---

## 9. VALIDEZ Y ACEPTACIÓN

### Validez

Esta propuesta es válida por **30 días naturales** a partir de la fecha de emisión. Pasado este plazo, los importes y alcances están sujetos a revisión.

### Aceptación

La aceptación de esta propuesta se formaliza mediante:

1. **Correo /whatsapp de aceptación** por el representante legal del cliente
2. **Pago del anticipo** del 30% ($18,000 + IVA)
3. **Confirmación por escrito** (correo electrónico es suficiente) del inicio de Fase 1

---

## 10. DATOS DE CONTACTO DEL PROVEEDOR

| Campo                  | Valor                          |
| ---------------------- | ------------------------------ |
| **Empresa**            | [Nombre de tu empresa / VCorp] |
| **Contacto comercial** | Frank Saavedra                 |
| **Email**              | **frank@vcorp.mx**             |
| **Teléfono**           | [Tu teléfono]                  |
| **Domicilio fiscal**   | [Dirección fiscal completa]    |
| **RFC**                | [Tu RFC]                       |

---

## 11. PRÓXIMOS PASOS

1. ✅ **Revisión de la propuesta económica** por el Ing. Francisco Aguirre
2. ✅ **Aclaración de dudas** vía correo o reunión (sugerido en los próximos 5 días)
3. ✅ **Aprobación formal** con firma y anticipo de $18,000 + IVA
4. ✅ **Inicio de Fase 1** (solicitud inmediata de credenciales a Siemens)
5. ✅ **Entrega Fase 2** (middleware funcional)
6. ✅ **Go-Live** (operación en producción)
7. ✅ **Después del go-live:** el cliente decide si adquiere soporte por evento o bolsa de horas (sección 3)

---

*Documento preparado por  Ing. Frank Saavedra | Vcorp — ID interno: ARCH-20260706-03*  

---

## 📋 Resumen ejecutivo para el cliente

| Concepto                         | Monto                                                                                    |
| -------------------------------- | ---------------------------------------------------------------------------------------- |
| **Implementación llave en mano** | **$60,000 MXN + IVA**                                                                    |
| **Anticipo requerido** (30%)     | **$18,000 MXN + IVA**                                                                    |
| **Plazo de ejecución**           | 9-10 semanas                                                                             |
| **Validez**                      | 30 días                                                                                  |
| **Soporte post go-live**         | Opcional: por evento ($1,500/h, mín. 2h) o bolsa prepagada (5/10/20 h con 10% descuento) |
| **Garantía incluida**            | 15 días post go-live                                                                     |