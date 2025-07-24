#!/bin/bash

# Crear archivo de log
LOG_FILE="/tmp/phantomjs-setup.log"

# Función para loggear con timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Iniciando instalación de PhantomJS ==="

# Instalar dependencias
log "📦 Instalando bzip2 y tar..."
dnf install -y bzip2 tar 2>&1 | tee -a "$LOG_FILE"

# Descargar PhantomJS
log "⬇️  Descargando PhantomJS..."
curl -LO https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 2>&1 | tee -a "$LOG_FILE"

# Verificar que se descargó correctamente
if [ ! -f "phantomjs-2.1.1-linux-x86_64.tar.bz2" ]; then
    log "❌ Error: No se pudo descargar PhantomJS"
    exit 1
fi
log "✅ PhantomJS descargado correctamente"

# Descomprimir
log "📂 Descomprimiendo PhantomJS..."
tar xf phantomjs-2.1.1-linux-x86_64.tar.bz2 2>&1 | tee -a "$LOG_FILE"

# Verificar que se descomprimió correctamente
if [ ! -f "./phantomjs-2.1.1-linux-x86_64/bin/phantomjs" ]; then
    log "❌ Error: No se pudo descomprimir PhantomJS"
    exit 1
fi
log "✅ PhantomJS descomprimido correctamente"

# Verificar permisos de ejecución
chmod +x ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs

# Mostrar información del binario
log ""
log "=== Información del binario PhantomJS ==="
ls -la ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs 2>&1 | tee -a "$LOG_FILE"
file ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs 2>&1 | tee -a "$LOG_FILE"

# Verificar dependencias con ldd
log ""
log "=== Dependencias de librerías (ldd) ==="
ldd ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs 2>&1 | tee -a "$LOG_FILE"

# Verificar si hay librerías faltantes
log ""
log "=== Verificando librerías faltantes ==="
ldd ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs | grep "not found" 2>&1 | tee -a "$LOG_FILE" || log "✅ Todas las librerías están disponibles"

log ""
log "=== Instalación completada ==="
log "PhantomJS está listo en: ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs"

# Mostrar ubicación del archivo de log
echo "📄 Log guardado en: $LOG_FILE" 