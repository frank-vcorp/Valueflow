@echo off
:: ============================================
:: Valueflow Middleware - Lanzador directo
:: Llamado por Inno Setup [Run] (con privilegios admin ya elevados)
:: ============================================

setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"

if not exist "%PS_SCRIPT%" (
    echo ============================================================
    echo  ERROR: No se encontro install.ps1
    echo ============================================================
    pause
    exit /b 1
)

:: Ejecutar install.ps1 directamente (sin prompts)
echo Ejecutando instalador...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

set "RC=%errorlevel%"
if not "%RC%"=="0" (
    echo.
    echo ============================================================
    echo  Instalacion finalizo con errores. Codigo: %RC%
    echo ============================================================
    timeout /t 5
) else (
    echo Instalacion completada.
    timeout /t 3
)
exit /b %RC%
