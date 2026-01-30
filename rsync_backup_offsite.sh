#!/bin/bash

# Carregar configurações do .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERRO: Ficheiro .env não encontrado em $SCRIPT_DIR"
    exit 1
fi

DEST_MOUNT="$OFFSITE_MOUNT_POINT"
SOURCE_MOUNT="$LOCAL_MOUNT_POINT"

# Configuração de Log Offsite (guarda no HDD_01 para ficar log centralizado)
# Se OFFSITE_LOG_FILE não estiver definido, cria padrão
if [ -z "$OFFSITE_LOG_FILE" ]; then
    OFFSITE_LOG_FILE="${SOURCE_MOUNT}/logs/backup_offsite.log"
fi

LOG_DIR=$(dirname "$OFFSITE_LOG_FILE")
mkdir -p "$LOG_DIR"
LOGFILE="${OFFSITE_LOG_FILE%.*}_$(date +%Y-%m-%d_%H-%M-%S).log"

echo "--- A iniciar Backup Offsite (Espelho 01 -> 02): $(date) ---" | tee -a "$LOGFILE"

# 1. Verifica se disco OFFSITE está montado
if ! mountpoint -q "$DEST_MOUNT"; then
    MSG="ABORTADO: O disco secundário ($DEST_MOUNT) NÃO está montado. O backup semanal foi ignorado."
    echo "$MSG" | tee -a "$LOGFILE"
    # Se não está montado, assumimos que não é semana de rotação ou esqueceram-se.
    # Pode-se optar por enviar alerta ou apenas logar. Aqui enviamos alerta WARN.
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Backup Offsite FALHOU: $MSG"
    fi
    exit 1
fi

# 2. Verifica se disco PRIMÁRIO está montado (Origem)
if ! mountpoint -q "$SOURCE_MOUNT"; then
    MSG="ERRO CRÍTICO: O disco primário ($SOURCE_MOUNT) não está montado! Impossível copiar."
    echo "$MSG" | tee -a "$LOGFILE"
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "$MSG"
    fi
    exit 1
fi

echo "Origem: $SOURCE_MOUNT (HDD 01)" >> "$LOGFILE"
echo "Destino: $DEST_MOUNT (HDD 02)" >> "$LOGFILE"

# 3. Executa Rsync (Espelho TOTAL)
# Copia tudo de 01 para 02.
# --delete: Garante que 02 fica EXATAMENTE igual a 01 (remove o que não existe em 01)
# Excluímos coisas de sistema ou temporárias se necessário (Trash, etc)
/usr/bin/rsync -av --delete \
    --exclude ".Trash*" \
    --exclude "System Volume Information" \
    --exclude " lost+found" \
    --log-file="$LOGFILE" \
    "$SOURCE_MOUNT/" "$DEST_MOUNT/"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "--- Sucesso: $(date) ---" >> "$LOGFILE"
    
    # Tenta desmontar o disco no final para segurança
    echo "A desmontar $DEST_MOUNT para remoção segura..." >> "$LOGFILE"
    sync
    umount "$DEST_MOUNT"
    UMOUNT_RES=$?
    
    if [ $UMOUNT_RES -eq 0 ]; then
        MSG_FINAL="Backup Offsite (Clone 01->02) CONCLUÍDO. O disco $DEST_MOUNT foi desmontado e pode ser removido."
    else
        MSG_FINAL="Backup Offsite CONCLUÍDO, mas falha ao desmontar $DEST_MOUNT. Remova com cuidado."
    fi

    echo "$MSG_FINAL" >> "$LOGFILE"
    
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "SUCCESS" "$MSG_FINAL"
    fi
else
    MSG="ERRO no rsync durante espelhamento Offsite. Ver log em HDD 01."
    echo "$MSG" >> "$LOGFILE"
    if [ -x "$SCRIPT_DIR/notify_zulip.sh" ]; then
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "$MSG"
    fi
    exit 1
fi
