#!/bin/bash

echo "=== Construyendo imagen Docker ==="
docker build -t phantomjs-setup .

echo ""
echo "=== Extrayendo archivo de log ==="
# Crear un contenedor temporal para extraer el archivo
CONTAINER_ID=$(docker create phantomjs-setup)
docker cp $CONTAINER_ID:/tmp/phantomjs-setup.log ./phantomjs-setup.log
docker rm $CONTAINER_ID

echo "✅ Archivo de log extraído: ./phantomjs-setup.log"
echo ""
echo "=== Contenido del log ==="
cat ./phantomjs-setup.log 