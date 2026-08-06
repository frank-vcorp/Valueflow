@echo off
:: ============================================
:: Valueflow Middleware - Lanzador directo
:: Llamado por Inno Setup [Run] (con privilegios admin ya elevados)
:: o por doble click en un PowerShell admin.
::
:: v1.3.0: SIN prompts, SIN elevación runtime, SIN confirmaciones.
:: Confia en que el instalable Inno Setup ya solicitó elevación.
:: ============================================

setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"

if not exist "%PS_SCRIPT%" (
    echo ============================================================
    echo  ERROR: No se encontro install.ps1
    echo  Ruta esperada: %PS_SCRIPT%
    echo ============================================================
    pause
    exit /b 1
)

:: Ejecutar install.ps1 directamente (sin prompts)
echo Ejecutando instalador...
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
