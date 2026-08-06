@echo off
:: ============================================
:: Valueflow Middleware - Lanzador directo con limpieza automatica
:: Llamado por Inno Setup [Run] (con privilegios admin ya elevados)
:: o por doble click en PowerShell admin.
::
:: v1.4.1: NUEVO - limpieza automatica de instalaciones anteriores
:: antes de iniciar la nueva instalacion.
:: Esto evita que el install.ps1 copie el bundle VIEJO de
:: C:\Program Files\siemens-middleware (que queda de instalaciones
:: anteriores) en lugar del bundle nuevo extraido del instalable.
:: ============================================

setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"

:: ============================================
:: BLOQUE DE LIMPIEZA AUTOMATICA - v1.4.1
:: ============================================
echo ============================================================
echo  LIMPIEZA AUTOMATICA - v1.4.1
echo ============================================================
echo.

:: Cerrar procesos Node y PM2 (si estan corriendo)
echo  [1/4] Cerrando procesos Node y PM2...
taskkill /F /IM node.exe /T 2>nul
taskkill /F /IM pm2.cmd /T 2>nul
echo         Listo.

:: Eliminar accesos directos del escritorio
echo  [2/4] Eliminando accesos directos del escritorio...
del /Q "%USERPROFILE%\Desktop\Valueflow Middleware.lnk" 2>nul
del /Q "%PUBLIC%\Desktop\Valueflow Middleware.lnk" 2>nul
del /Q "%ALLUSERSPROFILE%\Desktop\Valueflow Middleware.lnk" 2>nul
echo         Listo.

:: Eliminar carpetas de instalaciones anteriores
echo  [3/4] Eliminando carpetas de instalaciones anteriores...
set "INSTALL_PATHS=C:\apps\siemens-middleware;C:\Program Files\siemens-middleware;C:\apps\valueflow-middleware;C:\Temp\valueflow-middleware;C:\Temp\valueflow-middleware-v1.4.0"

for %%P in ("%INSTALL_PATHS:;=" "%") do (
    if exist "%%P" (
        echo         Eliminando: %%P
        rd /S /Q "%%P" 2>nul
    )
)
echo         Listo.

:: Eliminar entradas del registro (Panel de Control)
echo  [4/4] Limpiando registro de Windows...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Valueflow Middleware" /f 2>nul
reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Valueflow Middleware" /f 2>nul
echo         Listo.

echo.
echo  Limpieza completada. Iniciando instalacion...
echo ============================================================
echo.

:: Verificar que install.ps1 existe
if not exist "%PS_SCRIPT%" (
    echo ============================================================
    echo  ERROR: No se encontro install.ps1
    echo  Ruta esperada: %PS_SCRIPT%
    echo ============================================================
    pause
    exit /b 1
)

:: Ejecutar install.ps1 directamente (sin prompts)
echo  Ejecutando instalador...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

set "RC=%errorlevel%"
echo.
if not "%RC%"=="0" (
    echo ============================================================
    echo  Instalacion finalizo con errores. Codigo: %RC%
    echo ============================================================
    timeout /t 5
) else (
    echo Instalacion completada.
    timeout /t 3
)
exit /b %RC%
