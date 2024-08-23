#!/usr/bin/env bash
##########################################################################
# Shellscript:	synopsis - Install Maven
# Author     :	Marcelo Nogueira <marcelo.bojikian@gmail.com>
# Date       :	2024-08-15
# Category   :	java maven
##########################################################################
# Reference
#  Maven: https://maven.apache.org/download.cgi
#
##########################################################################
# Description
#
#  dependency:
#   - JDK
#
##########################################################################
# External variables: 
#  
# (optional) OFFICIAL_MVN=3.9.8
# (optional) OFFICIAL_MVN_SHA512=e5a034a255b5f940d2baa0db1b64bed6ccbc1f568da6b79e37acd92817809c273158f52b2e0e2b942020efc203202f1338f2580590c8fd0ee4fca9bc08679577
#
# (optional) M2_HOME_VALUE=/opt/apache-maven-3.9.8
#
##########################################################################

################################################# variables
readonly LOG_FILE="maven_$(date "+%Y-%m-%d %H:%M:%S").log"
readonly MAVEN_FILE=/etc/profile.d/maven.sh
###########################################################

############################################## dependencies
for check in 'tar' 'java' 'sha512sum'; do
    if ! which "$check" &>/dev/null; then
        echo "Must have $check installed" && exit 1
    fi
done
###########################################################

################################################# functions

# Função que exibe o log
log() { msg="${*:2}"; printf "$(date "+%Y-%m-%d %H:%M:%S") - [%s] - %s\n" "${1^^}" "${msg}"; }
# Função que exibe o spinner
show_spinner() { pid=$1; delay=0.1; spinner="|/-\\"; while [ -d "/proc/$pid" ]; do for i in $(seq 0 3); do printf "\r%s" "${spinner:$i:1}"; sleep $delay; done; done; printf "\r"; }
# Função para executar um comando com o spinner e registrando logs
run() { "$@" >> "${LOG_DIR}/$LOG_FILE" 2>&1 & pid=$!; show_spinner $pid; wait $pid; }
# Função para verificar se o arquivo esta correcto
sha512_check() { SHA512_FILE=$(sha512sum "$1" 2> /dev/null | awk '{print $1}'); [ "$SHA512_FILE" != "$2" ] && return 1 || return 0; }

set_maven_home() {

    MAVEM_PATH="$1"
    [ ! -d "$MAVEM_PATH" ] && MAVEM_PATH=/usr/share/maven
    
    echo "#!/bin/bash" | tee "$MAVEN_FILE" > /dev/null
    echo "export JAVA_HOME=\"$JAVA_PATH\"" | tee -a "$MAVEN_FILE" > /dev/null
    echo "export M2_HOME=\"$MAVEM_PATH\"" | tee -a "$MAVEN_FILE" > /dev/null
    echo "export PATH=\$PATH:\$M2_HOME/bin" | tee -a "$MAVEN_FILE" > /dev/null

    chmod 644 "$MAVEN_FILE"

}

install_mavem_Official_v3() {

    VERSION=$1        
    MAVEN_FOLDER=$(printf "/opt/apache-maven-%s" "${VERSION}")
    [ -d "$MAVEN_FOLDER" ] && return 0

    MAVEN_FILE=$(printf "apache-maven-%s-bin.tar.gz" "${VERSION}")
    MAVEN_URL=$(printf "https://dlcdn.apache.org/maven/maven-3/%s/binaries/%s" "${VERSION}" "${MAVEN_FILE}")

    TMP_FILE="/tmp/$MAVEN_FILE"
    
    if sha512_check "$TMP_FILE" "$OFFICIAL_MVN_SHA512"; then
        run  tar xf "$TMP_FILE" -C /opt
    else        
        wget -q --show-progress -O "$TMP_FILE" "$MAVEN_URL"
        if ! sha512_check "$TMP_FILE" "$OFFICIAL_MVN_SHA512"; then
            return 1
        fi
    fi

    return 0

}

prepare() {

    if [ -n "$1" ] && [ -f "$1" ];then 
        log info "Load $1"
        # shellcheck source=/dev/null
        source "$1"
    else
        LOG_DIR=/var/log/flagelscript
    fi

    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chown "$(whoami):$(whoami)" "$LOG_DIR"
    fi

    log info "Log on: $LOG_DIR/$LOG_FILE"

    log info "Atualização do APT"
    run apt update
    
}

install_dependency_manager() {

    log info "Instalação de Gerenciador do dependências:"

    log info "> Maven padrão"
    run apt install -y maven

    if [ -n "$OFFICIAL_MVN" ]; then

        log info "> Maven Official Archive \( versão $OFFICIAL_MVN \)"
        if ! install_mavem_Official_v3 "$OFFICIAL_MVN"; then
            log error "O SHA512 não corresponde ao esperado!"
            return 1
        fi

    fi

}

configure() {

    log info "Configuração de sistema:"

    log info "> Set M2_HOME"
    set_maven_home "$M2_HOME_VALUE"

    if [ "$M2_HOME_VALUE" != "$M2_HOME" ]; then
        log warn Reinicie para efetivar as alteracão
    fi

    # shellcheck source=/etc/profile
    source /etc/profile

}
###########################################################

################################################# Principal
log info "Install Maven"

prepare "$1"
install_dependency_manager
configure

log info "Maven done"
