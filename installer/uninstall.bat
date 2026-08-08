@echo off
:: ============================================
:: Valueflow Middleware - Desinstalador standalone
:: Permite eliminar la instalacion sin ir a Panel de Control.
:: Llamado por:
::   - Doble click directo (usuario final)
::   - Install.bat si se quiere revertir una instalacion fallida
:: ============================================

setlocal
set "SCRIPT_DIR=%~dp0"

echo ============================================================
echo  Valueflow Middleware - Desinstalador
echo ============================================================
echo.

:: Verificar permisos de administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Se requieren permisos de administrador.
    echo Solicitando elevacion...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b 0
)

:: Ubicaciones posibles de instalacion
set "INSTALL_DIRS=C:\apps\siemens-middleware C:\Program Files\siemens-middleware"

echo Buscando instalacion existente...
set "FOUND_DIR="
for %%D in (%INSTALL_DIRS%) do (
    if exist "%%D\middleware\package.json" (
        set "FOUND_DIR=%%D"
        echo   Encontrada en: %%D
    )
)

if "%FOUND_DIR%"=="" (
    echo.
    echo No se encontro ninguna instalacion del middleware en:
    for %%D in (%INSTALL_DIRS%) do echo   - %%D
    echo.
    echo Si instalaste en otra ubicacion, especifica la ruta:
    set /p "FOUND_DIR=Ruta de instalacion: "
    if not exist "%FOUND_DIR%\middleware\package.json" (
        echo No se encontro middleware\package.json en %FOUND_DIR%
        pause
        exit /b 1
    )
)

echo.
echo Instalacion encontrada: %FOUND_DIR%
echo.
set /p "CONFIRM=Confirmas la desinstalacion completa? (S/N): "
if /i not "%CONFIRM%"=="S" (
    echo Operacion cancelada.
    pause
    exit /b 0
)

echo.
echo Deteniendo servicio PM2...
powershell -NoProfile -Command "if (Get-Command pm2 -ErrorAction SilentlyContinue) { pm2 stop siemens-middleware 2>$null; pm2 delete siemens-middleware 2>$null; pm2 save 2>$null }"
echo   Hecho.

echo.
echo Eliminando servicio Windows de PM2 (si existe)...
powershell -NoProfile -Command "if (Get-Command pm2-startup -ErrorAction SilentlyContinue) { pm2-startup uninstall 2>$null }"
echo   Hecho.

echo.
echo Cerrando procesos Node del middleware...
powershell -NoProfile -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*siemens-middleware*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
echo   Hecho.

echo.
echo Eliminando archivos de la instalacion...
if exist "%FOUND_DIR%" (
    rmdir /s /q "%FOUND_DIR%"
    echo   Hecho: %FOUND_DIR% eliminado
) else (
    echo   La carpeta ya no existe.
)

echo.
echo Eliminando acceso directo del escritorio...
del "%USERPROFILE%\Desktop\Valueflow Middleware.lnk" 2>nul
del "%PUBLIC%\Desktop\Valueflow Middleware.lnk" 2>nul
echo   Hecho.

echo.
echo ============================================================
echo  Desinstalacion completa
echo ============================================================
echo.
echo Para reinstalar, ejecuta Valueflow-Setup.exe de nuevo.
echo.
pause
endlocal
