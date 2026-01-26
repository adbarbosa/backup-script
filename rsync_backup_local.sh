#!/bin/bash

# Carregar configurações do .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERRO: Ficheiro .env não encontrado em $SCRIPT_DIR"

        if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
            "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Ficheiro .env não encontrado em $SCRIPT_DIR"
        fi
    exit 1
fi

SOURCE="$SOURCE_PATH"
DEST="$RSYNC_DEST"

# Garante que o diretório de logs existe
LOG_DIR=$(dirname "$RSYNC_LOG_FILE")
mkdir -p "$LOG_DIR"

LOGFILE="${RSYNC_LOG_FILE%.*}_$(date +%Y-%m-%d_%H-%M-%S).log"

# Configura a pasta de arquivos deletados. Se a variável nova não existir, usa padrão antigo.
if [ -n "$RSYNC_DELETED_BASE_DIR" ]; then
    BACKUP_DIR="$RSYNC_DELETED_BASE_DIR/$(date +%Y-%m-%d_%H-%M)"
else
    BACKUP_DIR="$DEST/_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)"
fi

# Converte a string do .env em array
IFS=' ' read -r -a REQUIRED_MOUNTS <<< "$REQUIRED_MOUNTS_LIST"

# 1. Verifica se a NAS está montada (Origem)
for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE}${mount}"; then
        MSG="ERRO - A pasta de origem '${mount}' não está montada em ${SOURCE}. Abortando."
        echo "$(date): $MSG" | tee -a "$LOGFILE"
        if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
            "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local: $MSG"
        fi
        exit 1
    fi
done

# 2. Verifica se o disco externo está montado (Segurança)
# Se LOCAL_MOUNT_POINT estiver definido, verifica ele. 
if [ -n "$LOCAL_MOUNT_POINT" ]; then
    if ! mountpoint -q "$LOCAL_MOUNT_POINT"; then
       MSG="ERRO - O disco local ($LOCAL_MOUNT_POINT) não está montado. Abortando para evitar escrita na raiz."
       echo "$(date): $MSG" | tee -a "$LOGFILE"
       if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
          "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local: $MSG"
       fi
       exit 1
    fi
fi

# Verifica/Cria diretório de destino e diretório de deletados
mkdir -p "$DEST"
mkdir -p "$BACKUP_DIR"

echo "--- Início Backup Local (Rsync): $(date) ---" >> "$LOGFILE"
echo "Origem: $SOURCE" >> "$LOGFILE"
echo "Destino: $DEST" >> "$LOGFILE"
echo "Lixeira: $BACKUP_DIR" >> "$LOGFILE"

# Executa o rsync
# -a: archive mode (preserva permissões, datas, donos, grupos, etc)
# -v: verbose (detalhes no log)
# --delete: apaga no destino ficheiros que já não existem na origem (Sync/Espelho)
# --backup --backup-dir: move ficheiros apagados/alterados para a pasta de segurança
# --exclude: evita copiar as pastas de backups antigos para dentro de si mesmas (loop infinito) se estiverem na raiz
# --progress: mostra barra de progresso (útil para execução manual)
rsync -av --progress --delete \
    --backup --backup-dir="$BACKUP_DIR" \
    --exclude "_ELIMINADOS" \
    --log-file="$LOGFILE" \
    "$SOURCE" "$DEST"

# Verifica o estado de saída do rsync
if [ $? -eq 0 ]; then
    echo "--- Sucesso: $(date) ---" >> "$LOGFILE"
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "SUCCESS" "Rsync Local concluído com sucesso."
    fi
else
    echo "--- FALHA: $(date) - Ocorreram erros no rsync ---" >> "$LOGFILE"
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local falhou. Verifique o log em $LOGFILE"
    fi
fi
