# Procedimiento: Levantar Firebird 2.5 + FlameRobin después de un reinicio

**Fecha:** 2026-08-05 22:35 CST
**Sesión:** ATLAS-20260805-02
**Aplicabilidad:** Ubuntu 26.04 LTS con Firebird 2.5 Classic + FlameRobin 0.9.13 instalados manualmente.

---

## TL;DR (3 comandos)

```bash
# 1. Verificar/levantar Firebird
sudo systemctl start firebird-classic

# 2. Verificar conectividad
ss -lnt | grep ':3050'                      # debe mostrar LISTEN
pgrep -af fb_inet_server                    # debe haber procesos firebird

# 3. Arrancar FlameRobin GUI
flamerobin
# En la GUI: localhost | /var/lib/firebird/SAE90EMPRE01.FDB | SYSDBA | masterkey
```

Si algún paso falla, ver secciones de troubleshooting abajo.

---

## 1. Arquitectura instalada

```
┌─────────────────────────────────────────────────────────────┐
│ Ubuntu 26.04 LTS                                             │
│                                                              │
│  ┌──────────────────────────────────┐                       │
│  │ systemd: firebird-classic.service │                       │
│  │   └─ /opt/firebird/bin/fb_inet_server -m                  │
│  │      (User=firebird Group=firebird)│                       │
│  │   └─ Listen: 0.0.0.0:3050 (TCP)  │                       │
│  └──────────────────────────────────┘                       │
│                                                              │
│  ┌──────────────────────────────────┐                       │
│  │ /usr/bin/flamerobin (wrapper)    │                       │
│  │   └─ exec sg firebird + LD_PRELOAD │                       │
│  │   └─ /usr/bin/flamerobin.real    │                       │
│  └──────────────────────────────────┘                       │
│                                                              │
│  Data:                                                        │
│    /opt/firebird/             (instalación Firebird, ~221 arch)│
│    /var/lib/firebird/SAE90EMPRE01.FDB  (BD, 786 MB)         │
│    /var/lib/firebird/tmp/     (TmpDirectory para lock files) │
│    /tmp/firebird/             (trace files)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Procedimiento de arranque después de reinicio

### 2.1 Estado normal (sin intervención)

`firebird-classic.service` está **habilitado** (`systemctl enable`), así que systemd lo levanta automáticamente en boot. No requiere acción manual.

```bash
# Verificar
systemctl is-active firebird-classic      # debe devolver "active"
ss -lnt | grep ':3050'                    # debe mostrar LISTEN 0.0.0.0:3050
```

### 2.2 Si el servicio NO está activo

```bash
sudo systemctl start firebird-classic
sleep 2
systemctl is-active firebird-classic      # debe ser "active"
ss -lnt | grep ':3050'                    # debe mostrar LISTEN
```

### 2.3 Si el puerto no escucha pese a "active"

El servicio puede estar activo pero el binario crasheó. Reiniciar:

```bash
sudo systemctl restart firebird-classic
sleep 2
systemctl status firebird-classic         # ver log del servicio
sudo journalctl -u firebird-classic -n 30 --no-pager
```

### 2.4 Limpiar zombies en `/tmp/firebird` (opcional, recomendado)

Si hay archivos de lock con owner **frank:frank** o cualquier usuario que no sea `firebird:firebird`, limpiarlos:

```bash
# Ver qué hay
ls -la /tmp/firebird/
# Esperado tras uso: fb_init, fb_trace, fb_trace_* (todos firebird:firebird 660)
# Si hay zombies con owner frank:
sudo rm -f /tmp/firebird/fb_lock_*
sudo rm -f /tmp/firebird/fb_init /tmp/firebird/fb_trace*  # solo si vas a reiniciar
sudo systemctl restart firebird-classic
```

### 2.5 Arrancar FlameRobin GUI

```bash
flamerobin
```

El wrapper `/usr/bin/flamerobin`:
1. Activa grupo `firebird` (necesario para leer `/opt/firebird/security2.fdb`)
2. Inyecta `LD_PRELOAD=/lib/x86_64-linux-gnu/libpthread.so.0` (evita libpthread de snap)
3. Fuerza `LC_ALL=C.UTF-8` (evita warning de locale)
4. Ejecuta `exec -a "flamerobin"` (mantiene argv[0] correcto → home dir `~/.flamerobin/`)

**Datos de conexión en FlameRobin GUI:**

| Campo | Valor |
|-------|-------|
| Server | `localhost` (o `127.0.0.1`) |
| Port | `3050` |
| Database path | `/var/lib/firebird/SAE90EMPRE01.FDB` |
| User | `SYSDBA` |
| Password | `masterkey` |
| Charset | `UTF8` (recomendado) |

---

## 3. Troubleshooting

### 3.1 "operating system directive open failed / Permission denied"

**Causa:** `/tmp/firebird/` tiene zombies con owner incorrecto, o el server no se reinició.

**Solución:**
```bash
# Limpiar y reiniciar
sudo rm -f /tmp/firebird/*
sudo systemctl restart firebird-classic
sleep 2
```

### 3.2 "Cannot attach to password database"

**Causa:** El cliente (FlameRobin) no está en grupo `firebird`. El wrapper ya lo arregla; si lo lanzas directo sin wrapper, fallará.

**Solución:**
```bash
# Verificar usuario en grupo
id | grep firebird        # debe mostrar "(firebird)"
# Si no está, agregar
sudo usermod -aG firebird $USER
# Hacer logout/login para que tome efecto

# O usar el wrapper
flamerobin                # siempre correcto
```

### 3.3 "Missing configuration file: /opt/firebird/firebird.conf, exiting"

**Causa:** `firebird.conf` no es propiedad de root o no existe. **El binario Firebird 2.5 requiere que ese archivo sea root:root mode 0644** (verificado por strace).

**Solución:**
```bash
# Verificar
ls -la /opt/firebird/firebird.conf
# Esperado: -rw-r--r-- 1 root root

# Reparar si está mal
sudo chown root:root /opt/firebird/firebird.conf
sudo chmod 644 /opt/firebird/firebird.conf
sudo systemctl restart firebird-classic
```

**Contenido correcto de `/opt/firebird/firebird.conf`:**
```
# Configuración para Firebird 2.5 Classic
# Ubicación del lock dir y archivos temporales
TmpDirectory = /var/lib/firebird/tmp
```

### 3.4 FlameRobin arranca pero no muestra datos / se cierra

**Causa:** Problema de locale o de libpthread de snap.

**Solución:**
```bash
# Verificar locales disponibles
locale -a | grep -E '(en_US|es_ES)'
# Si falta en_US.UTF-8:
sudo locale-gen en_US.UTF-8
sudo update-locale

# Verificar wrapper
ls -la /usr/bin/flamerobin /usr/bin/flamerobin.real
# El wrapper DEBE tener 3 líneas con sg firebird, LD_PRELOAD y exec -a

# Si el wrapper está roto, restaurar (ver sección 4.2)
```

### 3.5 Sudo expirado frecuentemente durante automatización

**Causa:** Ubuntu 26.04 usa `sudo-rs` (Rust) que es más estricto con TTY.

**Solución para scripts automatizados:**
```bash
# Cachear password al inicio y mantenerlo
echo 'TU_PASSWORD' | sudo -S -v
# Inmediatamente después, ejecutar todos los comandos sin esperar
sudo COMANDO_QUE_NEECESITES_SUDO
```

Si sudo expira entre comandos, re-cachear con el mismo método.

---

## 4. Comandos de referencia rápida

### 4.1 Diagnóstico completo

```bash
# Estado del servicio
systemctl status firebird-classic --no-pager

# Procesos
pgrep -af fb_inet_server

# Puerto
ss -lnt | grep ':3050'

# Logs
sudo journalctl -u firebird-classic -n 30 --no-pager
sudo cat /opt/firebird/firebird.log | tail -20

# Lock files
ls -la /tmp/firebird/

# Test conexión rápida
echo "SELECT CURRENT_USER FROM RDB\$DATABASE;" | \
  sudo -u firebird /opt/firebird/bin/isql \
  localhost/3050:/var/lib/firebird/SAE90EMPRE01.FDB \
  -user SYSDBA -pass masterkey
```

### 4.2 Restaurar el wrapper de FlameRobin

Si `/usr/bin/flamerobin` se corrompe:

```bash
# Restaurar binario original
sudo cp /tmp/flamerobin.real.preserve /usr/bin/flamerobin.real
sudo chmod 755 /usr/bin/flamerobin.real

# Crear wrapper
sudo tee /usr/bin/flamerobin >/dev/null <<'EOF'
#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
exec -a "flamerobin" sg firebird -c "LD_PRELOAD=/lib/x86_64-linux-gnu/libpthread.so.0 /usr/bin/flamerobin.real $*"
EOF
sudo chmod 755 /usr/bin/flamerobin
```

### 4.3 Restaurar permisos de archivos críticos

```bash
# /opt/firebird propiedad de firebird
sudo chown -R firebird:firebird /opt/firebird

# firebird.conf DEBE ser root:root 644
sudo chown root:root /opt/firebird/firebird.conf
sudo chmod 644 /opt/firebird/firebird.conf

# BD con permisos 660 firebird:firebird
sudo chown firebird:firebird /var/lib/firebird/SAE90EMPRE01.FDB
sudo chmod 660 /var/lib/firebird/SAE90EMPRE01.FDB

# TmpDirectory
sudo mkdir -p /var/lib/firebird/tmp
sudo chown firebird:firebird /var/lib/firebird/tmp
sudo chmod 770 /var/lib/firebird/tmp

# Lock dir /tmp/firebird
sudo mkdir -p /tmp/firebird
sudo chown firebird:firebird /tmp/firebird
sudo chmod 770 /tmp/firebird

# Reiniciar
sudo systemctl restart firebird-classic
```

---

## 5. Por qué NO se usa `install.sh` ni xinetd

Esta instalación fue **manual** por las siguientes incompatibilidades del paquete Firebird 2.5 (sep 2010) con Ubuntu 26.04:

| Componente del paquete original | Problema | Solución aplicada |
|---------------------------------|----------|-------------------|
| `install.sh` SysV-init interactivo | Requiere password de SYSDBA por stdin interactivo, no automatizable con `sudo -S` | Extracción manual de `buildroot.tar.gz` |
| xinetd + `user = firebird` en config | xinetd + sudo-rs lanza el proceso como UID actual del shell (frank), no como firebird | Migrado a **systemd unit** directo con `User=firebird` |
| `firebird.conf` propiedad de firebird | El binario valida que sea root y falla con "Missing configuration file" | Config en `/opt/firebird/firebird.conf` con owner `root:root 644` |
| `security2.fdb` 660 firebird:firebird | Cliente que no está en grupo firebird no puede leerla | FlameRobin wrapper fuerza `sg firebird` antes de ejecutar |

**Implicación para futuras máquinas:**
- El paquete `FirebirdCS-2.5.0.26074-0.amd64.tar.gz` en `repaga-siemens/` puede reutilizarse
- NO ejecutar `install.sh`; usar el procedimiento manual documentado en `analysis/VALIDACION_BD_FIREBIRD_20260805_R2.md` sección 2
- NO instalar xinetd; configurar systemd directamente
- SIEMPRE crear `/opt/firebird/firebird.conf` con `TmpDirectory` apuntando a dir propiedad de firebird

---

## 6. Uninstall

Si necesitas desinstalar todo:

```bash
# Detener servicios
sudo systemctl stop firebird-classic
sudo systemctl disable firebird-classic

# Eliminar archivos
sudo /opt/firebird/uninstall.sh   # script casero creado durante instalación

# O manualmente:
sudo rm -rf /opt/firebird /var/lib/firebird /tmp/firebird
sudo userdel firebird 2>/dev/null
sudo groupdel firebird 2>/dev/null
sudo rm /etc/systemd/system/firebird-classic.service
sudo systemctl daemon-reload

# FlameRobin
sudo apt remove --purge flamerobin
sudo rm /usr/bin/flamerobin.real
```

---

## 7. Resumen de archivos clave

| Archivo | Propósito | Permisos correctos |
|---------|-----------|---------------------|
| `/opt/firebird/firebird.conf` | Config del server | `root:root 644` |
| `/opt/firebird/security2.fdb` | BD de autenticación | `firebird:firebird 660` |
| `/opt/firebird/firebird.log` | Log del server | `firebird:firebird 666` |
| `/opt/firebird/databases.conf` | Alias de BDs | `firebird:firebird 660` |
| `/etc/systemd/system/firebird-classic.service` | Unit file systemd | `root:root 644` |
| `/usr/bin/flamerobin` | Wrapper GUI | `root:root 755` |
| `/usr/bin/flamerobin.real` | Binario GUI original | `root:root 755` |
| `/var/lib/firebird/SAE90EMPRE01.FDB` | BD del cliente | `firebird:firebird 660` |
| `/var/lib/firebird/tmp/` | TmpDirectory configurado | `firebird:firebird 770` |
| `/tmp/firebird/` | Trace files generados | `firebird:firebird 770` |

---

**Última validación:** 2026-08-05 22:35 CST — Firebird activo, puerto 3050 LISTEN, FlameRobin arranca, query a factura 47333 retorna 2 partidas correctamente.
