# Valueflow — Integración Aspel SAE 10 ↔ Siemens PoSi

[![Node.js](https://img.shields.io/badge/Node.js-20%20LTS-green)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-blue)](https://www.typescriptlang.org)
[![Status](https://img.shields.io/badge/Status-Ready%20to%20Install-success)]()

Middleware de integración que automatiza el envío de **inventario** y **ventas** desde Aspel SAE 10 hacia el portal Siemens PoSi, con UI local de administración y operación desatendida.

---

## 🎯 ¿Qué hace?

Automatiza dos flujos diarios de información hacia Siemens:

| Flujo | Datos | Método | Frecuencia |
|-------|-------|--------|------------|
| **Envío de Inventario** | Existencias por producto y almacén | API REST | Diario 02:00 AM |
| **Value Flow (Ventas)** | Facturas y remisiones filtradas por marca Siemens | API REST | Diario 03:00 AM |

**Filtro clave:** Solo se reportan a Siemens los productos cuya línea (`LIN_PROD`) pertenece a las 15 líneas Siemens configuradas. Las "corridas" y productos de otras marcas NO se envían.

---

## 🏗️ Arquitectura

```
┌─────────────────────────┐         ┌─────────────────────────────┐
│  Aspel SAE 10            │         │  Siemens PoSi Portal        │
│  (Firebird 5.0)          │         │  (api.pos.siemens.com)      │
│                         │         │                              │
│  ┌─────────────────┐    │ localhost│  ┌────────────────────┐   │
│  │ INVE/FACTE/FACTT│◀───┼─────────┼──│ /qua/inventory/... │   │
│  │ (BD Firebird)   │    │  :3050  │  │ /qua/ (PoS)         │   │
│  └─────────────────┘    │         │  └────────────────────┘   │
│           │              │         │                              │
│           ▼              │         │                              │
│  ┌─────────────────┐    │  HTTP   │                              │
│  │   MIDDLEWARE    │────┼─────────┼──▶  QUA / PRD                │
│  │ (Node.js + TS)  │    │  :443   │                              │
│  │  + PM2 Service  │    │         │                              │
│  └─────────────────┘    │         │                              │
│           │              │         │                              │
│           ▼              │         │                              │
│  ┌─────────────────┐    │         │                              │
│  │  UI localhost   │    │         │                              │
│  │  :4567 (Basic   │    │         │                              │
│  │   Auth)         │    │         │                              │
│  └─────────────────┘    │         │                              │
└─────────────────────────┘         └─────────────────────────────┘
```

---

## ✨ Características

- ✅ **Acceso directo a Firebird 5.0** (sin pasar por reportes de SAE)
- ✅ **Filtro de marca Siemens** por `LIN_PROD` (15 líneas)
- ✅ **Solo campos básicos requeridos** (5 inventario, 10 ventas)
- ✅ **Campos opcionales seleccionables** desde UI (toggles individuales)
- ✅ **API Key editable desde UI** sin reinicio del servicio
- ✅ **UI local con logos corporativos** (Repaga + Approved Partner Siemens)
- ✅ **Cron jobs independientes** (un fallo no afecta al otro)
- ✅ **Reintentos robustos** con backoff exponencial
- ✅ **Logs estructurados** (Winston + JSON, retención 90 días)
- ✅ **API Key nunca se loguea completa** (enmascaramiento `I1k****gbv`)
- ✅ **Auto-arranque** como Servicio Windows (PM2)
- ✅ **Aislamiento total de errores** entre jobs

---

## 📁 Estructura del repositorio

```
.
├── README.md                                ← Este archivo
├── PROYECTO.md                              ← Estado del proyecto (IDL)
├── .gitignore
├── proposals/                               ← Documentos comerciales
│   ├── PROPUESTA_TECNICA_SAE10_SIEMENS.{md,pdf}
│   ├── PROPUESTA_ECONOMICA_SAE10_SIEMENS.{md,pdf}
│   ├── CORREO_PRESENTACION.md
│   ├── REPORTE_CONEXION_SIEMENS.{pdf,html}
│   └── MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md
├── analysis/                                ← Análisis técnico
│   ├── MAPEO_CAMPO_A_CAMPO.{md,pdf}
│   ├── ESQUEMA_BD_SAE.md
│   ├── SAE10_SIEMENS_INTEGRATION_ANALYSIS.md
│   ├── SIEMENS_INTEGRATION_EXTRACT.md
│   ├── VERIFICACION_CRUZADA_FINAL.md
│   └── REPORTE_PRUEBAS_INTEGRACION.md
├── specs/                                   ← Especificaciones técnicas
│   └── SPEC-IMPL-20260721-01-siemens-middleware.md
├── middleware/                              ← Código fuente del middleware
│   ├── src/
│   │   ├── index.ts                         ← Entry point
│   │   ├── config/                          ← .env + config.json
│   │   ├── db/                              ← Firebird + queries
│   │   ├── siemens/                         ← API client + transformadores
│   │   ├── scheduler/                       ← Cron jobs independientes
│   │   ├── logger/                          ← Winston
│   │   ├── jobs/                            ← runInventory + runSales
│   │   └── ui/                              ← Express + vistas HTML
│   ├── public/                              ← Logo Repaga + badge Siemens
│   ├── tests/                               ← Tests unitarios
│   ├── package.json
│   ├── tsconfig.json
│   ├── ecosystem.config.js                  ← PM2
│   ├── .env.example
│   ├── config.json.example
│   ├── README.md                            ← Manual de instalación
│   └── MANUAL_OPERACION.md                  ← Manual del usuario
├── assets/                                  ← Imágenes corporativas
│   ├── logo_aga_letras_2.png
│   └── partner.png
└── checkpoints/                             ← Checkpoints del proyecto
    └── CHK-FINAL-20260721-01.md
```

---

## 🚀 Instalación rápida

### Requisitos
- **Windows 10/11** o Windows Server 2019+
- **Aspel SAE 10** con Firebird 5.0 (incluye `fbclient.dll`)
- **Node.js 20 LTS** ([descargar](https://nodejs.org))
- Permisos de administrador para instalar como Servicio Windows
- **API Key de Siemens** (QAS o PRD) — solicitar a Siemens Data Steward

### Pasos

```powershell
# 1. Crear directorio de instalación
mkdir C:\apps\siemens-middleware
cd C:\apps\siemens-middleware

# 2. Copiar código del repositorio
# (git clone o copiar archivos)

# 3. Instalar dependencias
npm install

# 4. Compilar TypeScript
npm run build

# 5. Configurar variables de entorno
copy .env.example .env
notepad .env
# Editar:
#   FIREBIRD_PASSWORD=<password_solo_lectura>
#   UI_PORT=4567
#   UI_USERNAME=admin
#   UI_PASSWORD_HASH=<bcrypt_hash>
#   LOG_DIR=C:\apps\siemens-middleware\logs

# 6. Generar hash bcrypt para UI
node -e "console.log(require('bcryptjs').hashSync('MiPasswordSeguro', 12))"
# Pegar el resultado en UI_PASSWORD_HASH del .env

# 7. Configurar config operativa
copy config.json.example config.json
# Editar:
#   siemens.base_url: "https://api.pos.siemens.com"
#   siemens.environment: "qua"  (o "prd" para producción)
#   siemens.distributor_sender_id: "MX-REPRESENTACIONES"
#   firebird.db_path: "C:/Program Files/Aspel/Aspel SAE 10.0/BD/SAE10.FDB"
#   firebird.user: "readonly_siemens_user"

# 8. Iniciar con PM2 (auto-arranque como Servicio Windows)
npm install -g pm2
npm install -g pm2-windows-startup
pm2-startup install
pm2 start ecosystem.config.js
pm2 save

# 9. Verificar
pm2 status
pm2 logs siemens-middleware

# 10. Abrir UI en navegador
start http://localhost:4567
```

### Excluir del antivirus (importante)
- Excluir `C:\apps\siemens-middleware\`
- Excluir `C:\Program Files\nodejs\`

---

## 🎨 UI (capturas)

La UI está disponible en `http://localhost:4567` con autenticación Basic Auth.

| Vista | Función |
|-------|---------|
| **Dashboard** | Estado de jobs (Inventario + Ventas), historial de ejecuciones |
| **Configuración** | Editar `distributor_sender_id`, ambiente, líneas Siemens, campos opcionales, **API Key** |
| **Acciones** | Ejecutar jobs manualmente, test de conexión Siemens, test de conexión SAE |
| **Logs** | Ver y descargar logs del día |
| **Diagnóstico** | Versiones, rutas, enmascaramiento de API Key |

**Header de la UI** muestra:
- Logo de Representaciones Aga de Saltillo (izquierda)
- Indicador de ambiente (QUA/PRD) + badge **Siemens Approved Partner - Value Added Reseller** (derecha)

---

## 🧪 Pruebas y validación

El proyecto fue validado contra:

| Validación | Resultado |
|-----------|-----------|
| Conexión a Firebird 5.0 real | ✅ 21,805 productos en líneas Siemens detectados |
| Facturas con líneas mixtas (Siemens + no-Siemens) | ✅ Filtro SQL aplica correctamente (CFDI_32670: 4 de 6 líneas) |
| Autenticación contra API Siemens QUA | ✅ HTTP 201 Created con payload válido |
| Esquema de campos | ✅ 5 requeridos inventario, 10 requeridos ventas confirmados |
| Intermitencia del sandbox QUA | ⚠️ Documentado — 502 intermitentes, ir directo a PRD para go-live |
| UI end-to-end via Playwright | ✅ API Key editable, test funciona, logos visibles |

---

## 📚 Documentación adicional

- **[Manual de instalación completo](middleware/README.md)** — paso a paso detallado
- **[Manual de operación](middleware/MANUAL_OPERACION.md)** — para el usuario final (Ing. Paco)
- **[Propuesta técnica](proposals/PROPUESTA_TECNICA_SAE10_SIEMENS.md)** — arquitectura completa
- **[Mapeo campo a campo](analysis/MAPEO_CAMPO_A_CAMPO.md)** — equivalencias SAE ↔ Siemens
- **[SPEC técnica](specs/SPEC-IMPL-20260721-01-siemens-middleware.md)** — especificación para implementador
- **[Memorándum 502](proposals/MEMO_DIAGNOSTICO_ERROR_502_SIEMENS.md)** — diagnóstico de intermitencia QUA
- **[Checkpoint final](checkpoints/CHK-FINAL-20260721-01.md)** — resumen completo del proyecto

---

## 📞 Contacto

**Cliente:**
- Representaciones Aga de Saltillo
- Ing. Francisco Aguirre
- fcoaguirre@repaga.com.mx
- 844 160 6737

**Proveedor:**
- VCorp
- Frank Saavedra
- frank@vcorp.mx

---

## 📄 Licencia

Software propietario. Uso restringido a Representaciones Aga de Saltillo y VCorp.

---

*Desarrollado por VCorp con metodología asistida por IA (INTEGRA arquitectura + SOFIA implementación).*
*Stack: Node.js 20 LTS · TypeScript 5 · Express · HTMX · Tailwind CSS · Firebird 5.0 · Winston*
*Período de desarrollo: Julio 2026*
*Estado: Listo para instalación y go-live (pendiente OC del cliente)*