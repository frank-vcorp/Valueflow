@echo off
:: ============================================
:: Valueflow Middleware - Lanzador de instalador
:: Ejecuta install.ps1 con permisos de admin.
:: Llamado por:
::   - Inno Setup [Run] section (install.ps1 ya copiado)
::   - Doble click por usuario final
:: ============================================

setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"

if not exist "%PS_SCRIPT%" (
    echo.
    echo ============================================================
    echo  ERROR: No se encontro install.ps1
    echo  Ruta esperada: %PS_SCRIPT%
    echo ============================================================
    echo.
    pause
    exit /b 1
)

:: Verificar permisos de administrador (necesarios para PM2, firewall, etc.)
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: No somos admin - relanzar con elevación via PowerShell
    set "ELEV_PS=%TEMP%\valueflow_elevate_%RANDOM%.ps1"
    >  "%ELEV_PS%" echo $cmd = '"%~f0"'
    >> "%ELEV_PS%" echo Start-Process -FilePath $cmd -Verb RunAs -Wait
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ELEV_PS%"
    del "%ELEV_PS%" 2>nul
) else (
    :: Ya somos admin - ejecutar install.ps1 directamente
    echo ============================================================
    echo  Valueflow Middleware - Instalador
    echo ============================================================
    echo.
    pushd "%SCRIPT_DIR%"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
    set "RC=%errorlevel%"
    popd
    if not "%RC%"=="0" (
        echo.
        echo ============================================================
        echo  Instalacion finalizo con errores. Codigo: %RC%
        echo ============================================================
    ) else (
        echo.
        echo Instalacion completada.
    )
    timeout /t 5 >nul
    exit /b %RC%
)
