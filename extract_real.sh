#!/bin/bash

# Script mejorado para extraer librerías reales del contenedor
# Copia los archivos reales (con versiones) en lugar de los enlaces simbólicos
ROOT_DIR=$(pwd)

CONTAINER_NAME="a25f50e17d51"
DEST_DIR="$ROOT_DIR/libs"

# Crear directorio de destino
mkdir -p "$DEST_DIR"

echo "--- Extracción de librerías reales (con versiones) ---"
echo "Contenedor: $CONTAINER_NAME"
echo "Destino: $DEST_DIR"
echo ""

# Verificar que el contenedor esté ejecutándose
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Error: El contenedor '$CONTAINER_NAME' no está ejecutándose"
    exit 1
fi

# Lista de librerías con sus versiones reales (basado en el output de ls)
LIBS_VERSIONS=(
    "libz.so.1:libz.so.1.2.11"
    "libfontconfig.so.1:libfontconfig.so.1.12.0"
    "libfreetype.so.6:libfreetype.so.6.20.1"
    "libdl.so.2:libdl.so.2"
    "librt.so.1:librt.so.1"
    "libpthread.so.0:libpthread.so.0"
    "libstdc++.so.6:libstdc++.so.6.0.33"
    "libm.so.6:libm.so.6"
    "libgcc_s.so.1:libgcc_s-14-20250110.so.1"
    "libc.so.6:libc.so.6"
    "ld-linux-x86-64.so.2:ld-linux-x86-64.so.2"
    "libxml2.so.2:libxml2.so.2.10.4"
    "libbz2.so.1:libbz2.so.1.0.8"
    "libpng16.so.16:libpng16.so.16.37.0"
    "libharfbuzz.so.0:libharfbuzz.so.0.60700.0"
    "libbrotlidec.so.1:libbrotlidec.so.1.0.9"
    "liblzma.so.5:liblzma.so.5.2.5"
    "libglib-2.0.so.0:libglib-2.0.so.0.8200.2"
    "libgraphite2.so.3:libgraphite2.so.3.2.1"
    "libbrotlicommon.so.1:libbrotlicommon.so.1.0.9"
    "libpcre2-8.so.0:libpcre2-8.so.0.11.0"
)

echo "Copiando archivos reales desde /lib64/..."

# Copiar cada librería con su versión real
for lib_entry in "${LIBS_VERSIONS[@]}"; do
    lib_name="${lib_entry%:*}"
    real_file="${lib_entry#*:}"
    echo "Copiando: $lib_name -> $real_file"
    
    # Copiar el archivo real desde el contenedor
    docker cp "$CONTAINER_NAME:/lib64/$real_file" "$DEST_DIR/"
    
    # Renombrar al nombre estándar (sin versión)
    if [ -f "$DEST_DIR/$real_file" ]; then
        mv "$DEST_DIR/$real_file" "$DEST_DIR/$lib_name"
        echo "  ✅ $lib_name extraído correctamente"
    else
        echo "  ❌ Error copiando $lib_name"
    fi
done

echo ""
echo "--- Verificación final ---"

# Verificar que todos los archivos son reales (no enlaces)
for lib_entry in "${LIBS_VERSIONS[@]}"; do
    lib_name="${lib_entry%:*}"
    if [ -f "$DEST_DIR/$lib_name" ]; then
        if [ -L "$DEST_DIR/$lib_name" ]; then
            echo "⚠️  $lib_name es un enlace simbólico"
        else
            echo "✅ $lib_name - archivo real"
        fi
    else
        echo "❌ $lib_name - no encontrado"
    fi
done

echo ""
echo "--- Resumen ---"
echo "Archivos extraídos: $(ls -1 "$DEST_DIR" | wc -l)"
echo "Directorio: $DEST_DIR"
echo ""
echo "Para verificar que son archivos reales:"
echo "ls -la $DEST_DIR" 