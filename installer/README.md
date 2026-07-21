# Instalador de Valueflow Middleware para Windows

Este directorio contiene **3 formas** de instalar el middleware en Windows. Elige la que prefieras.

---

## 🚀 Opción 1 — Instalador profesional .exe (RECOMENDADO)

Genera un archivo `Valueflow-Setup-v1.0.exe` que el usuario simplemente ejecuta con doble click.

### Requisitos para compilar
- **Windows** (sí, necesitas compilar en Windows)
- **[Inno Setup 6.x](https://jrsoftware.org/isdl.php)** (gratis)

### Pasos

1. **Instala Inno Setup** desde https://jrsoftware.org/isdl.php
2. **Copia el instalador compilable** a Windows:
   - Todo el contenido de este directorio `installer/`
   - La carpeta `middleware/` completa
   - La carpeta `assets/` con los logos
3. **Compila** abriendo `installer.iss` en Inno Setup Compiler y haciendo click en "Compile"
4. El resultado aparece en `installer/output/Valueflow-Setup-v1.0.exe`
5. **Envía ese .exe** a Ing. Paco por correo o USB
6. El usuario final hace **doble click** en el .exe → Next → Next → Install → Finish

### Lo que hace el .exe
- ✅ Detecta Windows 7/8/10/11 y Server
- ✅ Verifica/instala Node.js 20 LTS
- ✅ Copia el middleware a `C:\apps\siemens-middleware\`
- ✅ Ejecuta `npm install --production`
- ✅ Compila TypeScript
- ✅ Solicita credenciales al usuario
- ✅ Genera `.env` y `config.json`
- ✅ Instala PM2 como Servicio Windows
- ✅ Crea acceso directo en escritorio
- ✅ Excluye del antivirus
- ✅ Crea entrada en Menú Inicio
- ✅ Desinstalador incluido en "Agregar o quitar programas"

---

## 🖥️ Opción 2 — Script PowerShell con .bat (sin compilar)

Si no quieres/puedes compilar un .exe, este método funciona directamente.

### Requisitos
- Windows 10/11 o Server 2019+
- Permisos de administrador

### Pasos

1. **Copia el contenido de este directorio** a la PC destino:
   - `install.ps1`
   - `install.bat`
2. **Coloca el middleware** en la misma carpeta donde están los scripts:
   ```
   📁 installer-pkg/
   ├── install.ps1
   ├── install.bat
   └── 📁 middleware/  ← aquí va todo el código del middleware
   ```
3. **Doble click** en `install.bat`
4. **Aceptar la elevación de UAC** (ventana de Windows pidiendo permisos)
5. El script descargará Node.js si hace falta, instalará todo, y abrirá la UI

### Comportamiento
- Si NO eres admin → `install.bat` solicita elevación automáticamente
- Si YA eres admin → ejecuta directamente
- Muestra progreso con colores (verde=OK, amarillo=advertencia, rojo=error)
- Abre la UI automáticamente al final

---

## 🔧 Opción 3 — Instalación manual (para sysadmins)

Si prefieres control total sobre cada paso, sigue el manual en:
- [`middleware/README.md`](../middleware/README.md) — Instalación manual paso a paso
- [`middleware/MANUAL_OPERACION.md`](../middleware/MANUAL_OPERACION.md) — Operación

### Resumen rápido
```powershell
# 1. Instalar Node.js 20 LTS
winget install OpenJS.NodeJS.LTS

# 2. Clonar el repo
git clone https://github.com/frank-vcorp/Valueflow.git
cd Valueflow\middleware

# 3. Instalar dependencias
npm install

# 4. Compilar
npm run build

# 5. Configurar
copy .env.example .env
copy config.json.example config.json
notepad .env
notepad config.json

# 6. Instalar PM2 globalmente
npm install -g pm2 pm2-windows-startup
pm2-startup install
pm2 start ecosystem.config.js
pm2 save

# 7. Abrir UI
start http://localhost:4567
```

---

## 📦 Cómo empaquetar para enviar al cliente

### Si compilaste el .exe (Opción 1)
- Envía solo `installer/output/Valueflow-Setup-v1.0.exe` por correo o USB
- El cliente no necesita nada más
- Tamaño: ~5-15 MB

### Si usas el script (Opción 2)
- Empaqueta la carpeta con los scripts + middleware:
  ```
  📁 valueflow-installer/
  ├── install.ps1
  ├── install.bat
  └── middleware/  ← código completo
  ```
- Comprime en `.zip` (~2-5 MB)
- Envía por correo
- El cliente extrae y ejecuta `install.bat`

---

## 🔧 Compilar el .exe desde Linux (opcional, requiere Wine)

Si quieres compilar en este entorno Linux, necesitas Wine + Inno Setup:

```bash
# Instalar Wine
sudo apt install wine64

# Descargar Inno Setup portable
wget https://jrsoftware.org/download.php/is.exe -O innosetup.exe
wine innosetup.exe /VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER

# Compilar
cd installer/
wine ~/.wine/drive_c/Program\ Files\ \(x86\)/Inno\ Setup\ 6/ISCC.exe installer.iss
```

El .exe compilado aparece en `installer/output/`.

---

## 📋 Estructura del directorio

```
installer/
├── install.ps1          ← Script PowerShell principal (250+ líneas)
├── install.bat          ← Wrapper .bat con auto-elevación admin
├── installer.iss        ← Script Inno Setup para generar .exe
├── README.md            ← Este archivo
└── (output/)            ← Aquí aparece el .exe compilado
```

---

## ❓ Troubleshooting

### "La ejecución de scripts está deshabilitada en este sistema"
```powershell
# Ejecutar PowerShell como admin:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "node no se reconoce como comando"
- Reiniciar la PC después de instalar Node.js
- Verificar PATH: `$env:Path -split ';' | Select-String node`

### "npm install falla con error de fbclient"
- Asegurarse de que Aspel SAE 10 está instalado (incluye `fbclient.dll`)
- Verificar: `Test-Path "C:\Program Files\Aspel\Aspel SAE 10.0\BD\SAE10.FDB"`

### "No se puede crear el servicio Windows"
- Ejecutar el script como **administrador** (clic derecho → "Ejecutar como administrador")

### La UI no responde
- Verificar que el servicio está corriendo: `pm2 status`
- Ver logs: `pm2 logs siemens-middleware`
- Reiniciar: `pm2 restart siemens-middleware`

---

## 📞 Soporte

Si hay problemas con el instalador:
- **Email:** frank@vcorp.mx
- **GitHub Issues:** https://github.com/frank-vcorp/Valueflow/issues

---

*Desarrollado por VCorp — Frank Saavedra*
*Para Representaciones Aga de Saltillo*