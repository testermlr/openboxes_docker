#!/bin/bash

# Colores para la salida
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Valores predeterminados
TOMCAT_PORT=8080
MYSQL_DB_NAME="openboxes"
MYSQL_PORT=3306
MYSQL_USERNAME="openboxes"
MYSQL_PASSWORD=$(openssl rand -base64 12)  # Generar una contraseña aleatoria segura
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)  # Generar una contraseña aleatoria segura

# Funciones
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}$1 no está instalado.${NC}"
        exit 1
    fi
}

install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${GREEN}Instalando Docker...${NC}"
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}Error al instalar Docker.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Docker ya está instalado.${NC}"
    fi
}

install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${GREEN}Instalando Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if ! command -v docker-compose &> /dev/null; then
            echo -e "${RED}Error al instalar Docker Compose.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Docker Compose ya está instalado.${NC}"
    fi
}

clone_repositories() {
    if [ ! -d "openboxes" ]; then
        echo -e "${GREEN}Clonando repositorio openboxes...${NC}"
        git clone https://github.com/openboxes/openboxes.git
    else
        echo -e "${GREEN}Repositorio openboxes ya existe.${NC}"
    fi

    if [ ! -d "openboxes-docker" ]; then
        echo -e "${GREEN}Clonando repositorio openboxes-docker...${NC}"
        git clone https://github.com/openboxes/openboxes-docker.git
    else
        echo -e "${GREEN}Repositorio openboxes-docker ya existe.${NC}"
    fi
}

configure_defaults() {
    echo -e "${GREEN}Configurando valores predeterminados...${NC}"

    # Modificar docker-compose.yml
    if [ -f "openboxes-docker/docker-compose.yml" ]; then
        cp openboxes-docker/docker-compose.yml openboxes-docker/docker-compose.yml.backup  # Hacer backup

        # Cambiar el puerto de Tomcat
        sed -i "s/8080:8080/$TOMCAT_PORT:8080/" openboxes-docker/docker-compose.yml

        # Cambiar configuración de MySQL
        sed -i "s/MYSQL_DATABASE: openboxes/MYSQL_DATABASE: $MYSQL_DB_NAME/" openboxes-docker/docker-compose.yml
        sed -i "s/MYSQL_USER: openboxes/MYSQL_USER: $MYSQL_USERNAME/" openboxes-docker/docker-compose.yml
        sed -i "s/MYSQL_PASSWORD: password/MYSQL_PASSWORD: $MYSQL_PASSWORD/" openboxes-docker/docker-compose.yml
        sed -i "s/MYSQL_ROOT_PASSWORD: rootpassword/MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASSWORD/" openboxes-docker/docker-compose.yml
    else
        echo -e "${RED}No se encontró el archivo docker-compose.yml. Asegúrate de haber clonado el repositorio openboxes-docker.${NC}"
        exit 1
    fi

    # Modificar openboxes-config.properties
    if [ -f "openboxes/openboxes-config.properties" ]; then
        cp openboxes/openboxes-config.properties openboxes/openboxes-config.properties.backup  # Hacer backup

        # Cambiar grails.serverUrl
        sed -i "s/grails.serverUrl=http:\/\/localhost:8080/grails.serverUrl=http:\/\/localhost:$TOMCAT_PORT/" openboxes/openboxes-config.properties

        # Cambiar configuración de la base de datos
        sed -i "s/dataSource.url=jdbc:mysql:\/\/localhost:3306\/openboxes/dataSource.url=jdbc:mysql:\/\/localhost:$MYSQL_PORT\/$MYSQL_DB_NAME/" openboxes/openboxes-config.properties
        sed -i "s/dataSource.username=openboxes/dataSource.username=$MYSQL_USERNAME/" openboxes/openboxes-config.properties
        sed -i "s/dataSource.password=password/dataSource.password=$MYSQL_PASSWORD/" openboxes/openboxes-config.properties
    else
        echo -e "${RED}No se encontró el archivo openboxes-config.properties. Asegúrate de haber clonado el repositorio openboxes.${NC}"
        exit 1
    fi
}

build_and_run_docker() {
    if [ -d "openboxes-docker" ]; then
        cd openboxes-docker || { echo -e "${RED}No se pudo acceder al directorio openboxes-docker.${NC}"; exit 1; }
        echo -e "${GREEN}Construyendo y ejecutando contenedores Docker...${NC}"
        if ! sudo docker-compose up --build; then
            echo -e "${RED}Error en la primera ejecución. Reintentando sin la bandera --build...${NC}"
            sudo docker-compose up
        fi
    else
        echo -e "${RED}El directorio openboxes-docker no existe. Asegúrate de haber clonado el repositorio.${NC}"
        exit 1
    fi
}

# Script principal
check_tool git
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl apt-transport-https ca-certificates software-properties-common openssl

install_docker
install_docker_compose
clone_repositories
configure_defaults
build_and_run_docker

# Mostrar tabla con valores de configuración
echo -e "${GREEN}Valores de configuración utilizados:${NC}"
printf "+---------------------+----------------+\n"
printf "| Parámetro           | Valor          |\n"
printf "+---------------------+----------------+\n"
printf "| Puerto de Tomcat    | %-14s |\n" "$TOMCAT_PORT"
printf "| Nombre de DB MySQL  | %-14s |\n" "$MYSQL_DB_NAME"
printf "| Puerto de MySQL     | %-14s |\n" "$MYSQL_PORT"
printf "| Usuario de MySQL    | %-14s |\n" "$MYSQL_USERNAME"
printf "| Contraseña MySQL    | %-14s |\n" "$MYSQL_PASSWORD"
printf "| Root pass de MySQL  | %-14s |\n" "$MYSQL_ROOT_PASSWORD"
printf "+---------------------+----------------+\n"
