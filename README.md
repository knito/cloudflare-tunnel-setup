# Cloudflare Tunnel Setup

Una guía completa para configurar y gestionar un túnel de Cloudflare usando `cloudflared`. Este proyecto proporciona un `Makefile` con comandos simplificados para todo el proceso.

## 🎯 Objetivo

Este túnel conecta múltiples servicios locales con el internet público a través de Cloudflare, permitiendo acceso seguro sin abrir puertos en el router o manejar certificados SSL.

## ✨ Características Principales

- 🚀 **Configuración completamente interactiva** - Sin variables hardcodeadas
- 🌐 **Soporte multi-hostname** - Configura múltiples servicios en un solo túnel  
- 🔄 **Re-despliegue seguro** - Actualiza configuraciones sin errores
- 📊 **Feedback detallado** - Resúmenes completos y listas de DNS records
- ⚡ **Validación integrada** - Previene configuraciones incorrectas
- 🛠️ **Comandos de gestión completos** - Todo el ciclo de vida del túnel

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

**Proceso interactivo:**
- Te pedirá el nombre del túnel que deseas crear
- Genera un archivo de credenciales único: `~/.cloudflared/{TUNNEL_ID}.json`
- Registra el túnel en tu cuenta de Cloudflare

### 4. Configurar Múltiples Ingress Rules (Crítico)

```bash
make tunnel-route
```

**Proceso interactivo mejorado:**
1. Te pedirá el nombre o UUID del túnel
2. Te pedirá el host por defecto (default: `192.168.1.10`)
3. **Loop para múltiples hostnames:**
   - Hostname (ej: `plex.midominio.com`)
   - Host del servicio (usa el default si presionas Enter)
   - Puerto del servicio (requerido)
   - Presiona Enter sin hostname para terminar
4. Genera automáticamente el archivo `~/.cloudflared/config.yml`
5. Muestra resumen completo de la configuración
6. Lista todos los registros DNS que necesitas crear

**Ejemplo de archivo de configuración generado:**
```yaml
tunnel: raspberrypi
credentials-file: ~/.cloudflared/raspberrypi.json
ingress:
  - hostname: plex.midominio.com
    service: http://192.168.1.10:32400
  - hostname: www.midominio.com
    service: http://192.168.1.10:80
  - hostname: api.midominio.com
    service: http://192.168.1.10:3000
  - service: http_status:503  # Catch-all para otros dominios
```

### 5. Configurar DNS en Cloudflare

Después de ejecutar `make tunnel-route`, necesitas crear un registro CNAME para cada dominio/subdominio que hayas configurado.

**Opción A: Manual en el Dashboard de Cloudflare (Recomendado para múltiples dominios)**
Esta es la forma más confiable si estás configurando hostnames que pertenecen a dominios distintos (ej: `.com` y `.cl`).
1. Entra a la zona del dominio correspondiente en Cloudflare
2. Ve a **DNS** -> **Records**
3. Añade un nuevo registro:
   - Tipo: `CNAME`
   - Nombre: `app` (para `app.midominio.com`)
   - Destino: `{TUNNEL_ID}.cfargotunnel.com`
   - Proxy status: Proxied (Nube naranja)

**Opción B: Via comando (Solo para el dominio principal)**
*⚠️ Nota: Este comando solo funciona para el dominio con el que te autenticaste en el paso 2.*
```bash
make tunnel-dns
```
- Te pedirá el nombre del túnel y el subdominio
- Crea automáticamente el registro DNS

### 6. Iniciar el Túnel

```bash
make tunnel-run
```

**Proceso interactivo:**
- Te pedirá el nombre o UUID del túnel a ejecutar
- Inicia el túnel en modo foreground
- Establece la conexión con Cloudflare
- Comienza a proxy el tráfico a todos los servicios configurados

## 🌐 Gestión de Múltiples Subdominios

### Configurar Múltiples Subdominios (Recomendado)

El comando `make tunnel-route` ahora soporta configuración de múltiples hostnames en una sola ejecución:

```bash
make tunnel-route
```

**Proceso:**
1. Introduce el nombre del túnel
2. Define el host por defecto (ej: `192.168.1.10`)
3. Agrega tantos hostnames como necesites:
   - `plex.midominio.com` → puerto `32400`
   - `www.midominio.com` → puerto `80` 
   - `api.midominio.com` → puerto `3000`
   - Presiona Enter sin hostname para terminar
4. El comando generará automáticamente toda la configuración
5. Te mostrará todos los registros DNS que necesitas crear

### Agregar Subdominios Adicionales

Para agregar más subdominios después de la configuración inicial:

1. **Vuelve a ejecutar la configuración:**
```bash
make tunnel-route
```
*Esto sobrescribirá la configuración existente, así que vuelve a agregar todos los hostnames*

2. **O edita manualmente:**
```bash
nano ~/.cloudflared/config.yml
```

3. **Crear registros DNS para cada subdominio:**
```bash
# Para cada subdominio nuevo
make tunnel-dns
# Ingresa: nombre del túnel
# Ingresa: subdominio (ej: api para api.midominio.com)
```

4. **Re-despliega el servicio:**
```bash
make tunnel-service-redeploy
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

### Re-desplegar el Servicio (Actualizar Configuración)

```bash
make tunnel-service-redeploy
```

**Qué hace:**
- Para y desinstala el servicio existente de forma segura
- Copia la configuración actualizada a `/etc/cloudflared/`
- Reinstala y reinicia el servicio con la nueva configuración
- Útil después de modificar hostnames con `make tunnel-route`

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

**Comandos disponibles:**
- `tunnel-install` - Instala cloudflared
- `tunnel-login` - Autenticación con Cloudflare  
- `tunnel-create` - Crear nuevo túnel
- `tunnel-route` - Configurar múltiples ingress rules
- `tunnel-run` - Ejecutar túnel
- `tunnel-dns` - Crear registros DNS
- `tunnel-info` - Información del túnel
- `tunnel-list` - Listar todos los túneles
- `tunnel-service-install` - Instalar como servicio systemd
- `tunnel-service-redeploy` - Re-desplegar servicio con nueva configuración  
- `tunnel-service-uninstall` - Desinstalar servicio

## ⚙️ Configuración Personalizada

**Configuración Interactiva (Recomendado):**

Todos los comandos ahora solicitan los valores necesarios interactivamente:
- **Nombres de túnel**: Se solicitan en cada comando que los requiera
- **Hostnames**: Configuración dinámica en `make tunnel-route`
- **Puertos de servicio**: Cada hostname puede tener su puerto específico
- **IPs de destino**: Host por defecto configurable, sobrescribible por hostname

**Valores por defecto:**
- Host por defecto: `192.168.1.10`
- Puerto por defecto para Plex: `32400`

**Variables comentadas en Makefile (no se usan activamente):**
```makefile
# K8S_HOST    := 192.168.1.10      # Comentado - ahora interactivo
# TUNNEL_NAME := "tunnel-name"     # Comentado - ahora interactivo
```

## ⚠️ Solución de Problemas Comunes

### Error al crear DNS en un dominio diferente (ej: sub.midominio.cl anidado en .com)
- **Causa:** El comando `make tunnel-dns` usa el certificado de tu autenticación inicial (ej: `midominio.com`). Si intentas crear un subdominio para otro dominio, lo anidará bajo el dominio autorizado (ej: `sub.midominio.cl.midominio.com`).
- **Solución:** Configura múltiples dominios en tu `config.yml` y luego crea los registros CNAME **manualmente** en el dashboard de Cloudflare para los dominios adicionales. El túnel SÍ funcionará para todos ellos.

### Error: "You have an existing certificate... which login would overwrite"
- **Causa:** Estás intentando correr `make tunnel-login` pero ya tienes un certificado para otro dominio.
- **Solución:** No necesitas volver a loguearte. Un solo túnel puede enrutar tráfico para múltiples dominios diferentes si creas los CNAME manualmente en Cloudflare apuntando al mismo UUID de túnel.

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