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

if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
    "$SCRIPT_DIR/notify_zulip.sh" "START" "Backup local a iniciar..."
fi

SUBFOLDER="$1"
# Remove barras finais do subfolder se existirem
SUBFOLDER="${SUBFOLDER%/}"

if [ -n "$SUBFOLDER" ]; then
    SOURCE="${SOURCE_PATH}${SUBFOLDER}/"
    DEST="${RSYNC_DEST}/${SUBFOLDER}/"
    JOB_INFO="Partial Backup: $SUBFOLDER"
    LOG_SUFFIX="_${SUBFOLDER//\//_}"
else
    SOURCE="$SOURCE_PATH"
    DEST="$RSYNC_DEST"
    JOB_INFO="Full Backup"
    LOG_SUFFIX=""
fi

# Garante que o diretório de logs existe
LOG_DIR=$(dirname "$RSYNC_LOG_FILE")
mkdir -p "$LOG_DIR"

LOGFILE="${RSYNC_LOG_FILE%.*}_$(date +%Y-%m-%d_%H-%M-%S)${LOG_SUFFIX}.log"

# Configura a pasta de arquivos deletados. Se a variável nova não existir, usa padrão antigo.
BACKUP_SUFFIX="_$(date +%Y-%m-%d_%H-%M)"

if [ -n "$RSYNC_DELETED_BASE_DIR" ]; then
    if [ -n "$SUBFOLDER" ]; then
         BACKUP_DIR="$RSYNC_DELETED_BASE_DIR/${SUBFOLDER}"
    else
         # Backup completo: usa a raiz do deleted (rsync preserva a estrutura de pastas)
         BACKUP_DIR="$RSYNC_DELETED_BASE_DIR"
    fi
else
    BACKUP_DIR="$DEST/_ELIMINADOS"
fi

# Converte a string do .env em array
IFS=' ' read -r -a REQUIRED_MOUNTS <<< "$REQUIRED_MOUNTS_LIST"

# Define quais mounts verificar
CHECK_MOUNTS=()
if [ -n "$SUBFOLDER" ]; then
    # Verifica se a subpasta é um dos mounts listados
    for mount in "${REQUIRED_MOUNTS[@]}"; do
        if [[ "$SUBFOLDER" == "$mount" ]] || [[ "$SUBFOLDER" == "$mount/"* ]]; then
             CHECK_MOUNTS+=("$mount")
        fi
    done
else
    CHECK_MOUNTS=("${REQUIRED_MOUNTS[@]}")
fi

# 1. Verifica se a NAS está montada (Origem)
# Usa SOURCE_PATH para verificar a raiz dos mounts
for mount in "${CHECK_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE_PATH}${mount}"; then
        MSG="ERRO - A pasta de origem '${mount}' não está montada em ${SOURCE_PATH}. Abortando."
        echo "$(date): $MSG" | tee -a "$LOGFILE"
        if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
            "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local ($JOB_INFO): $MSG"
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

/usr/bin/rsync -av --delete \
    --backup --backup-dir="$BACKUP_DIR" --suffix="$BACKUP_SUFFIX" \
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
