# CORREO DE PRESENTACIÓN — Propuestas Integración Siemens PoSi

**Para:** fcoaguirre@repaga.com.mx
**De:** frank@vcorp.mx
**Asunto:** Propuestas técnica y económica — Integración Aspel SAE 10 ↔ Siemens PoSi Portal
**Adjuntos:**
- `PROPUESTA_TECNICA_SAE10_SIEMENS.pdf` (ARCH-20260706-02)
- `PROPUESTA_ECONOMICA_SAE10_SIEMENS.pdf` (ARCH-20260706-03)

---

## Cuerpo del correo

Estimado Ing. Francisco Aguirre:

Espero que se encuentre bien. Le escribo para hacer llegar las propuestas correspondientes al proyecto de **integración entre su sistema Aspel SAE 10 y el portal Siemens PoSi**, que hemos venido analizando.

Como recordará, el objetivo es automatizar el envío de dos flujos de información a Siemens:

1. **Envío de Inventario** (diario, vía API REST — único método disponible en Siemens)
2. **Value Flow / Ventas** (diario, vía API REST o SFTP con CSV)

Ambas propuestas están adjuntas a este correo como documentos separados pero complementarios:

### 📋 Propuesta Técnica (ARCH-20260706-02)
Describe la arquitectura, stack tecnológico, alcance, fases, criterios de aceptación y consideraciones técnicas del proyecto. Incluye:
- Decisión de acceso directo a la base de datos Firebird 5.0 de SAE 10 (sin usar reportes)
- Middleware instalado en la misma PC donde corre SAE 10 (mínima latencia)
- UI local de administración para cambiar frecuencias y ver logs
- Particionamiento automático para los ~12,000 productos de su catálogo
- Stack: Node.js 20 LTS + TypeScript + driver nativo Firebird

### 💰 Propuesta Económica (ARCH-20260706-03)
Detalla la inversión, forma de pago y condiciones comerciales:
- **Inversión total:** $60,000 MXN + IVA
- **Cronograma:** 6 semanas (1 + 3 + 2)
- **Forma de pago:** 30% anticipo ($18,000 + IVA) / 40% al entregar Fase 2 / 30% al go-live exitoso
- **Soporte post go-live:** por intervención con presupuesto previo (sin mantenimiento mensual obligatorio)
- **Garantía:** 15 días posteriores al go-live incluidos

---

### 📌 Puntos importantes a destacar

1. **No requiere reuniones previas con Siemens.** Una vez aprobada la propuesta, solicitamos directamente al portal las API Keys, plantillas de campos y credenciales SFTP. Siemens las proporciona y arrancamos.

2. **No hay afectación a su licencia de Aspel SAE 10.** Trabajamos sobre la BD Firebird 5.0 que ya viene incluida — sin costos adicionales de software.

3. **El modelo de soporte post go-live es flexible.** Usted decide caso por caso si requiere soporte adicional; cada intervención se cotiza por separado previa aprobación escrita, sin compromisos mensuales.

4. **Plazo de validez:** Ambas propuestas son válidas por 30 días naturales a partir de hoy (6 de julio de 2026).

---

### 🔜 Próximos pasos sugeridos

1. **Revisión interna** de ambas propuestas con su equipo (sugerido en los próximos 5 días)
2. **Sesión de dudas** — con gusto agendamos una llamada o videollamada para resolver cualquier pregunta técnica o comercial
3. **Aprobación formal** — firma de aceptación + pago del anticipo de $18,000 + IVA
4. **Inicio de Fase 1** — solicitamos credenciales a Siemens de inmediato

Quedo a su disposición para cualquier aclaración o para agendar una sesión de presentación. Puede contactarme directamente a este correo o al WhatsApp [tu número].

Atentamente,

**[Tu nombre completo]**
[Tu cargo / posición]
[Tu empresa / VCorp]
📧 frank@vcorp.mx
📱 [Tu teléfono]
🏢 [Domicilio fiscal]

---

## 📎 Notas para ti (Frank) antes de enviar

1. **Convierte ambos `.md` a `.pdf`** con tu plantilla/membrete corporativo antes de adjuntar
2. **Revisa los placeholders** `[Tu ...]` en ambos documentos:
   - Nombre de tu empresa
   - Tu nombre completo
   - Tu cargo
   - Tu teléfono (WhatsApp)
   - Domicilio fiscal
   - RFC de Representaciones Aga de Saltillo (preguntar al cliente)
3. **Asigna los nombres finales de los archivos PDF:**
   - `PROPUESTA_TECNICA_SAE10_SIEMENS_v1.3_[Fecha].pdf`
   - `PROPUESTA_ECONOMICA_SAE10_SIEMENS_v1.5_[Fecha].pdf`
4. **Verifica que los archivos PDF estén bien formateados** antes de adjuntar (sin caracteres raros)
5. **Programar el envío** en horario laboral (9:00-11:00 AM tiene mejor tasa de apertura)

---

*Plantilla de correo generada el 2026-07-06 por INTEGRA*
*Documentos asociados: ARCH-20260706-02 (técnica) y ARCH-20260706-03 (económica)*