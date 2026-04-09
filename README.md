# Cloudflare Tunnel Setup

Una guía completa para configurar y gestionar un túnel de Cloudflare usando `cloudflared`. Este proyecto proporciona un `Makefile` con comandos simplificados para todo el proceso.

## 🎯 Objetivo

Este túnel conecta un servidor local (192.168.1.10) con el internet público a través de Cloudflare, permitiendo acceso seguro sin abrir puertos en el router o manejar certificados SSL.

## 📋 Prerrequisitos

- Una cuenta de Cloudflare con un dominio configurado
- Acceso al servidor donde se ejecutará el túnel
- Permisos sudo (para instalación del servicio systemd)

## 🚀 Configuración Paso a Paso

### 1. Instalación de cloudflared

```bash
make tunnel-install
```

**Qué hace:**
- En macOS: Instala via Homebrew
- En Linux ARM64: Descarga el binario y lo instala en `/usr/local/bin/`
- Verifica la instalación mostrando la versión

### 2. Autenticación con Cloudflare

```bash
make tunnel-login
```

**Qué hace:**
- Abre el navegador para autenticarte con Cloudflare
- Descarga el certificado a `~/.cloudflared/cert.pem`
- Este certificado permite crear y gestionar túneles

### 3. Crear el Túnel

```bash
make tunnel-create
```

**Qué hace:**
- Crea un túnel con el nombre `"tunnel-name"` (configurable en el Makefile)
- Genera un archivo de credenciales único: `~/.cloudflared/{TUNNEL_ID}.json`
- Registra el túnel en tu cuenta de Cloudflare

### 4. Configurar Ingress Rules (Crítico)

```bash
make tunnel-route
```

**Proceso interactivo:**
1. Te pedirá el nombre de dominio (ej: `app.midominio.com`)
2. Genera automáticamente el archivo `~/.cloudflared/config.yml`
3. Configura el tráfico para dirigirse a `http://192.168.1.10:NODE_PORT`

**Archivo de configuración generado:**
```yaml
tunnel: {TUNNEL_ID}
credentials-file: ~/.cloudflared/{TUNNEL_ID}.json
ingress:
  - hostname: app.midominio.com
    service: http://192.168.1.10:NODE_PORT
  - service: http_status:503  # Catch-all para otros dominios
```

### 5. Configurar DNS en Cloudflare

Después de ejecutar `make tunnel-route`, necesitas crear un registro CNAME:

**Opción A: Manual en el Dashboard de Cloudflare**
- Tipo: `CNAME`
- Nombre: `app` (para `app.midominio.com`)
- Destino: `{TUNNEL_ID}.cfargotunnel.com`

**Opción B: Via comando**
```bash
make tunnel-dns
```
- Te pedirá el nombre del túnel y el subdominio
- Crea automáticamente el registro DNS

### 6. Iniciar el Túnel

```bash
make tunnel-run
```

**Qué hace:**
- Inicia el túnel en modo foreground
- Establece la conexión con Cloudflare
- Comienza a proxy el tráfico al servidor local

## 🌐 Gestión de Subdominios

### Agregar Nuevos Subdominios

Para agregar múltiples subdominios al mismo túnel:

1. **Edita manualmente la configuración:**
```bash
nano ~/.cloudflared/config.yml
```

2. **Modifica la sección ingress:**
```yaml
tunnel: {TUNNEL_ID}
credentials-file: ~/.cloudflared/{TUNNEL_ID}.json
ingress:
  - hostname: app.midominio.com
    service: http://192.168.1.10:3000
  - hostname: api.midominio.com
    service: http://192.168.1.10:8080
  - hostname: admin.midominio.com
    service: http://192.168.1.10:9000
  - service: http_status:503
```

3. **Crear registros DNS para cada subdominio:**
```bash
# Para cada subdominio nuevo
make tunnel-dns
# Ingresa: nombre del túnel → api (para api.midominio.com)
# Ingresa: subdominio → api

# O manualmente en Cloudflare:
# CNAME: api → {TUNNEL_ID}.cfargotunnel.com
# CNAME: admin → {TUNNEL_ID}.cfargotunnel.com
```

4. **Reinicia el túnel:**
```bash
# Si está corriendo como servicio:
sudo systemctl restart cloudflared

# Si está corriendo en foreground:
# Ctrl+C y luego:
make tunnel-run
```

### Configuración Avanzada de Subdominios

**Servicios en diferentes puertos:**
```yaml
ingress:
  - hostname: web.midominio.com
    service: http://192.168.1.10:80
  - hostname: api.midominio.com
    service: http://192.168.1.10:3000
  - hostname: ws.midominio.com
    service: ws://192.168.1.10:8080  # WebSockets
  - service: http_status:503
```

**Diferentes protocolos:**
```yaml
ingress:
  - hostname: ssh.midominio.com
    service: ssh://192.168.1.10:22
  - hostname: rdp.midominio.com
    service: rdp://192.168.1.10:3389
  - service: http_status:503
```

## 🔧 Instalación como Servicio (Recomendado para Producción)

### Instalar el Servicio Systemd

```bash
make tunnel-service-install
```

**Qué hace:**
- Copia configuraciones a `/etc/cloudflared/`
- Instala el servicio systemd
- Habilita auto-inicio en el boot
- Inicia el servicio inmediatamente

### Gestionar el Servicio

```bash
# Ver estado
sudo systemctl status cloudflared

# Ver logs en tiempo real
sudo journalctl -u cloudflared -f

# Reiniciar el servicio
sudo systemctl restart cloudflared

# Parar el servicio
sudo systemctl stop cloudflared

# Deshabilitar auto-inicio
sudo systemctl disable cloudflared
```

### Desinstalar el Servicio

```bash
make tunnel-service-uninstall
```

## 🔍 Comandos de Diagnóstico

### Ver Información del Túnel
```bash
make tunnel-info
# Te pedirá el nombre o UUID del túnel
```

### Listar Todos los Túneles
```bash
make tunnel-list
```

### Ver Ayuda Completa
```bash
make help
```

## ⚙️ Configuración Personalizada

El `Makefile` incluye estas variables configurables:

```makefile
K8S_HOST    := 192.168.1.10      # IP del servidor destino
TUNNEL_NAME := "tunnel-name"     # Nombre del túnel
```

Para cambiar estos valores, edita el `Makefile` o usa variables de entorno:

```bash
K8S_HOST=192.168.1.50 make tunnel-route
```

## ⚠️ Solución de Problemas Comunes

### Error: "tunnel not found"
- **Causa:** No has ejecutado `make tunnel-create`
- **Solución:** Ejecuta `make tunnel-create` antes de `make tunnel-route`

### Error: "config.yml not found"
- **Causa:** No has configurado las ingress rules
- **Solución:** Ejecuta `make tunnel-route` antes de `make tunnel-run`

### El túnel no responde
1. Verifica que el servicio local esté ejecutándose en el puerto especificado
2. Revisa los logs: `sudo journalctl -u cloudflared -f`
3. Verifica la configuración DNS en Cloudflare

### Problemas de permisos en systemd
- **Causa:** El servicio systemd requiere permisos de root
- **Solución:** Usa `sudo` para todos los comandos de `systemctl`

## 📁 Estructura de Archivos

```
~/.cloudflared/
├── cert.pem                    # Certificado de Cloudflare
├── {TUNNEL_ID}.json           # Credenciales del túnel
└── config.yml                 # Configuración de ingress

/etc/cloudflared/              # Usado por systemd service
├── cert.pem
├── {TUNNEL_ID}.json
└── config.yml
```

## 🔐 Seguridad

- Los archivos de credenciales contienen secretos sensibles
- Nunca commits estos archivos al repositorio
- El túnel usa encriptación TLS end-to-end
- Cloudflare maneja automáticamente los certificados SSL

## 📚 Referencias

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [cloudflared CLI Reference](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/)