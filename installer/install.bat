@echo off
:: ============================================
:: Valueflow Middleware - Instalador
:: Launcher con elevación automática de permisos
:: ============================================

:: Verificar si ya somos admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: No somos admin - solicitar elevación
    echo.
    echo ============================================================
    echo  Solicitando permisos de administrador...
    echo  Se abrira una ventana de UAC - selecciona "Si"
    echo ============================================================
    echo.

    :: Crear script temporal para elevación
    set "elevate_script=%temp%\valueflow_elevate_%random%.bat"

    > "%elevate_script%" echo @echo off
    >> "%elevate_script%" echo cd /d "%~dp0"
    >> "%elevate_script%" echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "install.ps1"

    :: Lanzar con elevación
    powershell -Command "Start-Process -FilePath '%elevate_script%' -Verb RunAs -Wait"

    :: Limpiar
    del "%elevate_script%" 2>nul

    echo.
    echo Instalacion finalizada. Esta ventana se cerrara automaticamente.
    timeout /t 5 >nul
) else (
    :: Ya somos admin - ejecutar directamente
    echo Ejecutando instalador con permisos de administrador...
    cd /d "%~dp0"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "install.ps1"
    if %errorlevel% neq 0 (
        echo.
        echo ERROR: La instalacion fallo. Codigo: %errorlevel%
        pause
    )
)