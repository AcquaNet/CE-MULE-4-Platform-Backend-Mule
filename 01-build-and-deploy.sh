#!/bin/bash

# Script para build y deploy de aplicación Mulesoft
# Lee los valores del POM.xml y ejecuta los comandos necesarios

set -e  # Detener el script si ocurre algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verificar que existe el archivo pom.xml
if [ ! -f "pom.xml" ]; then
    log_error "No se encontró el archivo pom.xml en el directorio actual"
    exit 1
fi

# Extraer valores del POM.xml usando comandos de Maven
log_info "Extrayendo información del pom.xml..."

GROUP_ID=$(mvn help:evaluate -Dexpression=project.groupId -q -DforceStdout)
ARTIFACT_ID=$(mvn help:evaluate -Dexpression=project.artifactId -q -DforceStdout)
VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
REPOSITORY_ID=$(mvn help:evaluate -Dexpression=project.distributionManagement.repository.id -q -DforceStdout)
REPOSITORY_URL=$(mvn help:evaluate -Dexpression=project.distributionManagement.repository.url -q -DforceStdout)

# Validar que se extrajeron los valores
if [ -z "$GROUP_ID" ] || [ -z "$ARTIFACT_ID" ] || [ -z "$VERSION" ]; then
    log_error "No se pudieron extraer los valores del pom.xml"
    exit 1
fi

log_info "Configuración detectada:"
echo "  GroupId: $GROUP_ID"
echo "  ArtifactId: $ARTIFACT_ID"
echo "  Version: $VERSION"
echo "  Repository ID: $REPOSITORY_ID"
echo "  Repository URL: $REPOSITORY_URL"
echo ""

# Nombres de archivos
MULE_APP_JAR="${ARTIFACT_ID}-${VERSION}-mule-application.jar"
TARGET_JAR="${ARTIFACT_ID}-${VERSION}.jar"

# Paso 1: Limpiar y empaquetar
log_info "Ejecutando mvn clean package..."
mvn clean package

if [ $? -ne 0 ]; then
    log_error "Falló el comando mvn clean package"
    exit 1
fi

# Verificar que se generó el archivo
if [ ! -f "target/$MULE_APP_JAR" ]; then
    log_error "No se generó el archivo target/$MULE_APP_JAR"
    exit 1
fi

# Paso 2: Copiar y renombrar el archivo
log_info "Copiando $MULE_APP_JAR a $TARGET_JAR..."
cp "target/$MULE_APP_JAR" "target/$TARGET_JAR"

if [ $? -ne 0 ]; then
    log_error "Falló la copia del archivo"
    exit 1
fi

# Paso 3: Deploy al repositorio
log_info "Deployando al repositorio $REPOSITORY_URL..."
mvn deploy:deploy-file \
    -DgroupId="$GROUP_ID" \
    -DartifactId="$ARTIFACT_ID" \
    -Dversion="$VERSION" \
    -DrepositoryId="$REPOSITORY_ID" \
    -Dpackaging=jar \
    -Dfile="target/$TARGET_JAR" \
    -Durl="$REPOSITORY_URL"

if [ $? -ne 0 ]; then
    log_error "Falló el deploy al repositorio"
    exit 1
fi

log_info "✓ Deploy completado exitosamente!"
log_info "Artefacto deployado: $GROUP_ID:$ARTIFACT_ID:$VERSION"