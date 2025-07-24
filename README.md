# Guía: Obtención de Binarios para PhantomJS en AWS Lambda

## 📋 Índice
1. [Configuración del Entorno Docker y estructura de carpetas](#configuración-del-entorno-docker-y-estructura-de-carpetas)
2. [Instalación y Análisis de PhantomJS](#instalación-y-análisis-de-phantomjs)
3. [Extracción de Librerías del Contenedor](#extracción-de-librerías-del-contenedor)
4. [Verificación de Dependencias](#verificación-de-dependencias)
5. [Creación del Lambda Layer](#creación-del-lambda-layer)

---

## 🐳 Configuración del Entorno Docker y estructura de carpetas

### 1.1 Crear el Dockerfile
Para empaquetar la aplicación, crearemos un Dockerfile que utiliza la imagen oficial de AWS para **Node.js 20** (utilizando la arquitectura x86, pues por defecto es ARM). El uso de estas imágenes base es fundamental, ya que garantiza que nuestro contenedor tenga un entorno idéntico al de AWS Lambda, evitando problemas de compatibilidad.

Puedes consultar todas las imágenes oficiales en el [Docker Hub de AWS Lambda](https://hub.docker.com/r/amazon/aws-lambda-nodejs).

```dockerfile
FROM amazon/aws-lambda-nodejs:20-x86_64
COPY src/ ${LAMBDA_TASK_ROOT}/src/
CMD [ "src/index.handler" ]
```

Adicional deberemos crear una carpeta `/src` donde tambien estara un pequeño script `index.js` como el siguiente:
```javascript
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: 'PhantomJS setup completed!',
            timestamp: new Date().toISOString(),
            event: event
        }),
    };
    return response;
};
```
> Nota: Esta parte de añadir el script queda en investigacion de si es obligatorio o necesario, puesto que al momento de hacer un build, o correr el contenedor falla, se implementa como un workaround al problema.

### 1.2 Crear docker-compose.yml

```yaml
services:
  phantomjs-lambda:
    build: .
    container_name: phantomjs-lambda
    platform: linux/amd64
    volumes:
      - ./logs:/tmp/logs
    environment:
      - AWS_LAMBDA_FUNCTION_MEMORY_SIZE=3008
      - AWS_LAMBDA_FUNCTION_TIMEOUT=900
```

### 1.3 Estructura de archivos
La siguiente estructura de archivos contiene dos carpetas llamadas libs y logs, donde en la primera guardaremos las librerias que extraigamos del contenedor, la segunda, sera una utilidad para obtener datos que nos vaya impriendo la consola, dado caso se requiera correr con un script de bash.

```
lib-layer/
├── Dockerfile
├── docker-compose.yml
├── src/
│   └── index.js
├── libs/
└── logs/
```

### 1.4 Ejecutar el contenedor
Ahora ejecutaremos el contenedor para comenzar a trabajar:

```bash
# Construir la imagen
docker-compose build

# Ejecutar el contenedor en modo detached
docker-compose up -d

# Verificar que el contenedor está ejecutándose
docker ps
```

---

## ⚙️ Instalación y Análisis de PhantomJS

### 2.1 Instalacion de dependencias
Primero ejecutaremos unas librerias necesarias, bzip2 y tar para descomprimir la libreria de phantomjs.

```bash
docker exec phantomjs-lambda dnf install -y bzip2 tar
```

### 2.2 Descarga y extracción de PhantomJS
Ahora descargaremos desde un repositorio phantonjs:
```bash
docker exec phantomjs-lambda curl -LO https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 && tar xf phantomjs-2.1.1-linux-x86_64.tar.bz2
```

### 2.3 Comprobar la descarga
```bash
docker exec phantomjs-lambda ls -l phantomjs-2.1.1-linux-x86_64/bin/phantomjs
```

### 2.4 Análisis de dependencias
Este paso es importante puesto que verificaremos que librerias instaladas en en nuestro contenedor y cuales comparte con el ejecutable de phantomjs, para eso utilizaremos el comando `ldd` seguido del ejecutable:
```bash
docker exec phantomjs-lambda ldd ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs
```

**Output esperado:**
```bash
	libz.so.1 => /lib64/libz.so.1 (0x00007fffff7ab000)
	libfontconfig.so.1 => not found
	libfreetype.so.6 => not found
	libdl.so.2 => /lib64/libdl.so.2 (0x00007fffff7a4000)
	librt.so.1 => /lib64/librt.so.1 (0x00007fffff79f000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fffff79a000)
	libstdc++.so.6 => /lib64/libstdc++.so.6 (0x00007fffff534000)
	libm.so.6 => /lib64/libm.so.6 (0x00007fffff459000)
	libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x00007fffff42b000)
	libc.so.6 => /lib64/libc.so.6 (0x00007fffff223000)
	/lib64/ld-linux-x86-64.so.2 (0x00007ffffffc8000)
```

Como se puede apreciar, las librerías `libfontconfig.so.1` y `libfreetype.so.6` aparecen como "not found". Esto significa que necesitamos instalarlas o extraerlas del contenedor.

---

## 📦 Extracción de Librerías del Contenedor

### 3.1 Instalar librerías faltantes
Primero, instalemos las librerías que faltan:

```bash
docker exec phantomjs-lambda dnf install -y fontconfig freetype
```

### 3.2 Verificar librerías disponibles
Ahora verifiquemos qué librerías están disponibles en el contenedor:

```bash
docker exec phantomjs-lambda ls -la /lib64/ | grep -E "(libz|libfontconfig|libfreetype|libdl|librt|libpthread|libstdc|libm|libgcc|libc|ld-linux)"
```

### 3.3 Extraer librerías específicas (archivos reales)
**⚠️ Importante:** Las librerías en `/lib64/` son enlaces simbólicos que apuntan a archivos con versiones específicas. Necesitamos extraer los archivos reales, no los enlaces.

Primero, identifiquemos las versiones reales de las librerías:

```bash
# Ver las versiones reales de las librerías
docker exec phantomjs-lambda ls -la /lib64/ | grep -E "(libz|libfontconfig|libfreetype|libdl|librt|libpthread|libstdc|libm|libgcc|libc|ld-linux)"
```

**Output esperado:**
```bash
lrwxrwxrwx 1 root root      14 Oct 25  2023 libz.so.1 -> libz.so.1.2.11
lrwxrwxrwx 1 root root      23 Jan 31  2023 libfontconfig.so.1 -> libfontconfig.so.1.12.0
lrwxrwxrwx 1 root root      21 Jul 25  2024 libfreetype.so.6 -> libfreetype.so.6.20.1
-rwxr-xr-x 1 root root    14488 May 30 12:39 libdl.so.2
-rwxr-xr-x 1 root root    14576 May 30 12:39 librt.so.1
-rwxr-xr-x 1 root root    14496 May 30 12:39 libpthread.so.0
lrwxrwxrwx 1 root root      19 Mar 22 01:32 libstdc++.so.6 -> libstdc++.so.6.0.33
-rwxr-xr-x 1 root root   891392 May 30 12:39 libm.so.6
lrwxrwxrwx 1 root root      25 Mar 22 01:32 libgcc_s.so.1 -> libgcc_s-14-20250110.so.1
-rwxr-xr-x 1 root root  2542768 May 30 12:39 libc.so.6
-rwxr-xr-x 1 root root   900752 May 30 12:39 ld-linux-x86-64.so.2
```

Ahora extraigamos los archivos reales (con versiones):

```bash
# Crear directorio para las librerías
mkdir -p libs

# Extraer archivos reales (con versiones específicas)
docker cp phantomjs-lambda:/lib64/libz.so.1.2.11 libs/
docker cp phantomjs-lambda:/lib64/libfontconfig.so.1.12.0 libs/
docker cp phantomjs-lambda:/lib64/libfreetype.so.6.20.1 libs/
docker cp phantomjs-lambda:/lib64/libdl.so.2 libs/
docker cp phantomjs-lambda:/lib64/librt.so.1 libs/
docker cp phantomjs-lambda:/lib64/libpthread.so.0 libs/
docker cp phantomjs-lambda:/lib64/libstdc++.so.6.0.33 libs/
docker cp phantomjs-lambda:/lib64/libm.so.6 libs/
docker cp phantomjs-lambda:/lib64/libgcc_s-14-20250110.so.1 libs/
docker cp phantomjs-lambda:/lib64/libc.so.6 libs/
docker cp phantomjs-lambda:/lib64/ld-linux-x86-64.so.2 libs/

# Renombrar a nombres estándar (sin versiones)
cd libs
mv libz.so.1.2.11 libz.so.1
mv libfontconfig.so.1.12.0 libfontconfig.so.1
mv libfreetype.so.6.20.1 libfreetype.so.6
mv libstdc++.so.6.0.33 libstdc++.so.6
mv libgcc_s-14-20250110.so.1 libgcc_s.so.1
cd ..
```

### 3.4 Verificar archivos extraídos
```bash
ls -la libs/
```

Deberías ver algo como:
```bash
total 12345
drwxr-xr-x  2 user user    4096 Jan 15 10:30 .
drwxr-xr-x 10 user user    4096 Jan 15 10:30 ..
-rwxr-xr-x  1 user user  107416 Oct 25  2023 libc.so.6
-rwxr-xr-x  1 user user   14488 May 30 12:39 libdl.so.2
-rwxr-xr-x  1 user user  325464 Jan 30  2023 libfontconfig.so.1
-rwxr-xr-x  1 user user  887120 Jul 25  2024 libfreetype.so.6
-rwxr-xr-x  1 user user  190704 Mar 21 20:36 libgcc_s.so.1
-rwxr-xr-x  1 user user  900752 May 30 12:39 ld-linux-x86-64.so.2
-rwxr-xr-x  1 user user  891392 May 30 12:39 libm.so.6
-rwxr-xr-x  1 user user    14496 May 30 12:39 libpthread.so.0
-rwxr-xr-x  1 user user    14576 May 30 12:39 librt.so.1
-rwxr-xr-x  1 user user 2556800 Mar 21 20:36 libstdc++.so.6
-rwxr-xr-x  1 user user  107416 Oct 25  2023 libz.so.1
```

---

## 🔍 Verificación de Dependencias

### 4.1 Verificar que no hay enlaces simbólicos
**⚠️ CRÍTICO:** Es fundamental verificar que los archivos extraídos son binarios reales y no enlaces simbólicos. Los enlaces simbólicos no funcionarán en AWS Lambda.

```bash
# Verificar que no hay enlaces simbólicos (no debe mostrar 'l' al inicio)
ls -la libs/ | grep -v "^l"

# Verificar específicamente que no hay enlaces simbólicos
ls -la libs/ | grep "^l" && echo "❌ ERROR: Se encontraron enlaces simbólicos" || echo "✅ Todos los archivos son binarios"
```

**Output esperado (correcto):**
```bash
✅ Todos los archivos son binarios reales
```

**Output incorrecto (si hay enlaces simbólicos):**
```bash
lrwxrwxrwx 1 user user 14 Jan 15 10:30 libz.so.1 -> libz.so.1.2.11
❌ ERROR: Se encontraron enlaces simbólicos
```

### 4.2 Verificar dependencias adicionales
Algunas librerías pueden tener dependencias adicionales. Vamos a verificar:

```bash
# Verificar dependencias de fontconfig
docker exec phantomjs-lambda ldd /lib64/libfontconfig.so.1

# Verificar dependencias de freetype
docker exec phantomjs-lambda ldd /lib64/libfreetype.so.6
```

### 4.3 Extraer dependencias adicionales si es necesario
Si encuentras librerías adicionales que faltan, extráelas también:

```bash
# Ejemplo: si necesitas libxml2, libpng, etc.
docker cp phantomjs-lambda:/lib64/libxml2.so.2 libs/
docker cp phantomjs-lambda:/lib64/libpng16.so.16 libs/
docker cp phantomjs-lambda:/lib64/libharfbuzz.so.0 libs/
docker cp phantomjs-lambda:/lib64/libbrotlidec.so.1 libs/
docker cp phantomjs-lambda:/lib64/liblzma.so.5 libs/
docker cp phantomjs-lambda:/lib64/libglib-2.0.so.0 libs/
docker cp phantomjs-lambda:/lib64/libgraphite2.so.3 libs/
docker cp phantomjs-lambda:/lib64/libbrotlicommon.so.1 libs/
docker cp phantomjs-lambda:/lib64/libpcre2-8.so.0 libs/
```

---

## 🏗️ Creación del ZIP de Librerías

### 5.1 Crear ZIP de la carpeta libs
Una vez que tengas todas las librerías extraídas en la carpeta `libs/`, simplemente crea un ZIP:

```bash
# Crear ZIP de las librerías
cd libs
zip -r ../phantomjs-libs.zip .
cd ..

# Verificar el tamaño del ZIP
ls -lh phantomjs-libs.zip
```

### 5.2 Verificar contenido del ZIP
```bash
# Ver contenido del ZIP
unzip -l phantomjs-libs.zip

# Deberías ver algo como:
Archive:  phantomjs-libs.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
   107416  2023-10-25 12:00   libc.so.6
    14488  2023-05-30 12:39   libdl.so.2
   325464  2023-01-30 12:00   libfontconfig.so.1
   887120  2024-07-25 12:00   libfreetype.so.6
   190704  2023-03-21 20:36   libgcc_s.so.1
   900752  2023-05-30 12:39   ld-linux-x86-64.so.2
   891392  2023-05-30 12:39   libm.so.6
    14496  2023-05-30 12:39   libpthread.so.0
    14576  2023-05-30 12:39   librt.so.1
  2556800  2023-03-21 20:36   libstdc++.so.6
   107416  2023-10-25 12:00   libz.so.1
---------                     -------
  6031624                     11 files
```

---


### Troubleshooting

#### Error de Enlaces Simbólicos
**Problema:** `lrwxrwxrwx 1 user user 14 Jan 15 10:30 libz.so.1 -> libz.so.1.2.11`
**Causa:** Se extrajeron enlaces simbólicos en lugar de archivos reales
**Solución:** 
1. Eliminar archivos extraídos: `rm -rf libs/*`
2. Extraer archivos con versiones específicas (ver sección 3.3)
3. Renombrar a nombres estándar

#### Error "not found"
**Problema:** `libfontconfig.so.1 => not found`
**Causa:** Librerías no extraídas correctamente
**Solución:** Verifica que todas las dependencias estén extraídas

#### Error de permisos
**Problema:** `Permission denied`
**Causa:** Archivos sin permisos de ejecución
**Solución:** `chmod +x phantomjs/bin/phantomjs`

#### Error de arquitectura
**Problema:** `Platform mismatch`
**Causa:** Arquitectura incorrecta
**Solución:** Usa `--platform linux/amd64` en docker-compose

### Optimizaciones
- Usa solo las librerías necesarias para reducir el tamaño
- Considera usar librerías estáticas cuando sea posible
- Comprime el layer antes de subir si es muy grande

---

## 🎯 Comandos Rápidos

```bash
# Construir y ejecutar
docker-compose up -d

# Instalar dependencias
docker exec phantomjs-lambda dnf install -y bzip2 tar fontconfig-devel freetype-devel

# Descargar PhantomJS
docker exec phantomjs-lambda curl -LO https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 && tar xf phantomjs-2.1.1-linux-x86_64.tar.bz2

# Analizar dependencias
docker exec phantomjs-lambda ldd ./phantomjs-2.1.1-linux-x86_64/bin/phantomjs

# Extraer librerías (archivos reales)
mkdir -p libs && docker cp phantomjs-lambda:/lib64/libz.so.1.2.11 libs/ && mv libs/libz.so.1.2.11 libs/libz.so.1 && docker cp phantomjs-lambda:/lib64/libfontconfig.so.1.12.0 libs/ && mv libs/libfontconfig.so.1.12.0 libs/libfontconfig.so.1 && docker cp phantomjs-lambda:/lib64/libfreetype.so.6.20.1 libs/ && mv libs/libfreetype.so.6.20.1 libs/libfreetype.so.6

# Crear ZIP de librerías
cd libs && zip -r ../phantomjs-libs.zip . && cd ..

# Subir a AWS
aws lambda publish-layer-version --layer-name phantomjs-libs --zip-file fileb://phantomjs-libs.zip --compatible-runtimes nodejs20.x
```

## RECURSOS
- [How do you install phantomjs on AWS lambda?](https://stackoverflow.com/questions/56795567/how-do-you-install-phantomjs-on-aws-lambda)