#!/bin/bash

# Comando manual utilizado:
# rclone sync /mnt/003_ImagemUrbana/nas/ "ImagemUrbanaBackup:Backup_Empresa" --backup-dir "ImagemUrbanaBackup:Backup_Empresa_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)" --log-file="/home/adb/Development/003_ImagemUrbana/backup-script/backup_rclone.log" --log-level INFO --progress --checksum --use-mmap


# Carregar configurações do .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERRO: Ficheiro .env não encontrado em $SCRIPT_DIR"
    exit 1
fi

SUBFOLDER="$1"
# Remove barras finais do subfolder se existirem
SUBFOLDER="${SUBFOLDER%/}"

if [ -n "$SUBFOLDER" ]; then
    SOURCE="${SOURCE_PATH}${SUBFOLDER}/"
    DEST="${RCLONE_DEST}/${SUBFOLDER}/"
    # Adiciona subfolder também no diretorio de backup para manter organização
    BACKUP_DIR="${RCLONE_BACKUP_DIR_BASE}/${SUBFOLDER}/$(date +%Y-%m-%d_%H-%M)"
    JOB_INFO="Partial Backup: $SUBFOLDER"
    LOG_SUFFIX="_${SUBFOLDER//\//_}"
else
    SOURCE="$SOURCE_PATH"
    DEST="$RCLONE_DEST"
    # Mantém comportamento original para backup completo
    BACKUP_DIR="${RCLONE_BACKUP_DIR_BASE}/$(date +%Y-%m-%d_%H-%M)"
    JOB_INFO="Full Backup"
    LOG_SUFFIX=""
fi

# Garante que o diretório de logs existe
LOG_DIR=$(dirname "$RCLONE_LOG_FILE")
mkdir -p "$LOG_DIR"

LOGFILE="${RCLONE_LOG_FILE%.*}_$(date +%Y-%m-%d_%H-%M-%S)${LOG_SUFFIX}.log"

# Converte a string do .env em array
IFS=' ' read -r -a REQUIRED_MOUNTS <<< "$REQUIRED_MOUNTS_LIST"

# Define quais mounts verificar
CHECK_MOUNTS=()
if [ -n "$SUBFOLDER" ]; then
    for mount in "${REQUIRED_MOUNTS[@]}"; do
        if [[ "$SUBFOLDER" == "$mount" ]] || [[ "$SUBFOLDER" == "$mount/"* ]]; then
             CHECK_MOUNTS+=("$mount")
        fi
    done
else
    CHECK_MOUNTS=("${REQUIRED_MOUNTS[@]}")
fi

# Verifica se as pastas obrigatórias estão montadas
# Usa SOURCE_PATH (raiz) para verificar
for mount in "${CHECK_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE_PATH}${mount}"; then
        MSG="ERRO - A pasta '${mount}' não está montada em ${SOURCE_PATH}. Abortando."
        echo "$(date): $MSG" >> "$LOGFILE"
        if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
             "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rclone GDrive ($JOB_INFO): $MSG"
        fi
        exit 1
    fi
done

echo "--- Início: $(date) ---" >> "$LOGFILE"

/usr/bin/rclone sync "$SOURCE" "$DEST" \
    --backup-dir "$BACKUP_DIR" \
    --log-file="$LOGFILE" \
    --log-level INFO \
    --checksum \
    --use-mmap

EXIT_CODE=$?

echo "--- Fim: $(date) ---" >> "$LOGFILE"

if [ $EXIT_CODE -eq 0 ]; then
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "SUCCESS" "Rclone GDrive concluído com sucesso. ($JOB_INFO)"
    fi
else
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rclone GDrive falhou. ($JOB_INFO) Verifique o log em $LOGFILE"
    fi
fi