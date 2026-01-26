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

SOURCE="$SOURCE_PATH"
DEST="$RCLONE_DEST"
# Pasta de arquivo com data e hora
BACKUP_DIR="${RCLONE_BACKUP_DIR_BASE}/$(date +%Y-%m-%d_%H-%M)"
LOGFILE="$RCLONE_LOG_FILE"

# Converte a string do .env em array
IFS=' ' read -r -a REQUIRED_MOUNTS <<< "$REQUIRED_MOUNTS_LIST"

# Verifica se todas as pastas obrigatórias estão montadas
for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE}${mount}"; then
        MSG="ERRO - A pasta '${mount}' não está montada. Abortando."
        echo "$(date): $MSG" >> "$LOGFILE"
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rclone GDrive: $MSG"
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
    "$SCRIPT_DIR/notify_zulip.sh" "SUCCESS" "Rclone GDrive concluído com sucesso."
else
    "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rclone GDrive falhou. Verifique o log em $LOGFILE"
fi