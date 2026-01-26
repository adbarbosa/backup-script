#!/bin/bash

# Comando manual utilizado:
# rclone sync /mnt/003_ImagemUrbana/nas/ "ImagemUrbanaBackup:Backup_Empresa" --backup-dir "ImagemUrbanaBackup:Backup_Empresa_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)" --log-file="/home/adb/Development/003_ImagemUrbana/backup-script/backup_rclone.log" --log-level INFO --progress --checksum --use-mmap


SOURCE="/mnt/003_ImagemUrbana/nas/"
DEST="ImagemUrbanaBackup:Backup_Empresa"
# Pasta de arquivo com data e hora
BACKUP_DIR="ImagemUrbanaBackup:Backup_Empresa_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)"
LOGFILE="/home/adb/Development/003_ImagemUrbana/backup-script/backup_rclone.log"

# Lista de pastas que DEVEM estar montadas (ATENÇÃO: Edite esta lista com os nomes reais das suas pastas)
REQUIRED_MOUNTS=("adb" "DISCO_IU" "DISCO_IU_NEW" "DISCO_IU_XXX" "Public" "software" "backup" "gestao_documental" "ifthen" "portal" "Concursos_Publicos")

# Verifica se todas as pastas obrigatórias estão montadas
for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE}${mount}"; then
        echo "$(date): ERRO - A pasta '${mount}' não está montada. Abortando." >> "$LOGFILE"
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

echo "--- Fim: $(date) ---" >> "$LOGFILE"