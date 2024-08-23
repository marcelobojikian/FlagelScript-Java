#!/usr/bin/env bash
##########################################################################
# Shellscript:	synopsis - Install Java Development Kit
# Author     :	Marcelo Nogueira <marcelo.bojikian@gmail.com>
# Date       :	2024-08-15
# Category   :	java jdk
##########################################################################
# Reference
#  Orable JDK: https://www.oracle.com/ie/java/technologies/downloads
#
##########################################################################
# Description
#
#  Para alterar a versão do java de modo interativo pro terminal:
#  ~# sudo update-alternatives --config java
#
##########################################################################
# External variables: 
#
# (optional) ORACLE_JDK=22
# (optional) ORACLE_JDK_SHA256=799f6219d3ed1bdbab474656fb9f34397b22c8a441c35f87a1a8e771b19b4baa
# 
# (optional) JAVA_HOME_VALUE=/usr/lib/jvm/jdk-22.0.2-oracle-x64
#
##########################################################################

################################################# variables
readonly LOG_FILE="java_$(date "+%Y-%m-%d %H:%M:%S").log"
readonly JDK_PATH="/usr/lib/jvm"
readonly JAVA_FILE=/etc/profile.d/java.sh
###########################################################

############################################## dependencies
for check in 'dpkg' 'sha256sum'; do
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
sha256_check() { SHA256_FILE=$(sha256sum "$1" 2> /dev/null | awk '{print $1}'); [ "$SHA256_FILE" != "$2" ] && return 1 || return 0; }

set_java_home() {

    JAVA_PATH="$1"
    [ ! -d "$JAVA_PATH" ] && JAVA_PATH=/usr/lib/jvm/default-java
    
    echo "#!/bin/bash" | tee "$JAVA_FILE" > /dev/null
    echo "export JAVA_HOME=\"$JAVA_PATH\"" | tee -a "$JAVA_FILE" > /dev/null
    echo "export PATH=\$PATH:\$JAVA_HOME/bin" | tee -a "$JAVA_FILE" > /dev/null

    chmod 644 "$JAVA_FILE"
    
}

install_oracle_jdk() {

    VERSION=$1
    ORACLE_FILE=$(printf "jdk-%s_linux-x64_bin.deb" "${VERSION}")
    ORACLE_URL=$(printf "https://download.oracle.com/java/%s/latest/%s" "${VERSION}" "${ORACLE_FILE}")

    TMP_FILE="/tmp/$ORACLE_FILE"
        
    ORACLE_FOLDER=$(printf "$JDK_PATH/jdk-*%s*.*.*-oracle-*" "${VERSION}")
    for x in $ORACLE_FOLDER; do [ -d "$x" ] && return 0 && break; done
    
    if sha256_check "$TMP_FILE" "$ORACLE_JDK_SHA256"; then
        run dpkg -i "/tmp/$ORACLE_FILE"
    else        
        wget -q --show-progress -O "$TMP_FILE" "$ORACLE_URL"
        if ! sha256_check "$TMP_FILE" "$ORACLE_JDK_SHA256"; then
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

install_language() {

    log info "Instalação do Java Development Kit:"

    log info "> JDK padrão"
    run apt install -y default-jdk

    if [ -n "$ORACLE_JDK" ]; then

        log info "> Oracle JDK \( versão $ORACLE_JDK \)"
        if ! install_oracle_jdk "$ORACLE_JDK"; then
            log error "O SHA256 não corresponde ao esperado!"
            return 1
        fi
          
    fi

}

configure() {

    log info "Configuração de sistema:"

    log info "> Set JAVA_HOME"
    set_java_home "$JAVA_HOME_VALUE"

    if [ "$JAVA_HOME_VALUE" != "$JAVA_HOME" ]; then
        log warn Reinicie para efetivar a alteracão
    fi

    # shellcheck source=/etc/profile
    source /etc/profile

}
###########################################################

################################################# Principal
log info "Install Java Development Kit"

prepare "$1"
install_language
configure

log info "Java Development Kit done"
