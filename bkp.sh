#!/bin/bash

# Estado da informação de debug
DEBUG=true
echo "Debug is $DEBUG"

# Carregar configurações do .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERRO: Ficheiro .env não encontrado."
    exit 1
fi

LOG_PATH="$LEGACY_LOG_PATH"
LOG_FILE="log_adb_$(date +"%Y%m%d_%H%M%S").log"

NAME="adb"

BKP_FROM_MOUNT_POINT="/mnt/nas/adb"
BKP_FROM_PATH="${BKP_FROM_MOUNT_POINT}/"

BKP_TO_MOUNT_POINT="/mnt/bkp_drive"
BKP_TO_PATH="${BKP_TO_MOUNT_POINT}/adb/"

BKP_HISTORY_PATH="$LEGACY_HISTORY_PATH"

echo "log file: $LOG_FILE";

mount_point_is_ok() {
	MSG="$2 path ($1)"
    if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] Test $MSG" >> "$LOG_PATH$LOG_FILE"; fi
    if mount | grep "$1" > /dev/null; then 
        if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG is OK" >> "$LOG_PATH$LOG_FILE"; fi
        return 0 # Retorna true (código de saída 0)
    else
        if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG is NOK" >> "$LOG_PATH$LOG_FILE"; fi
        curl --data "user=$SMS_USER&password=$SMS_PASS&api_id=$SMS_API_ID&to=$SMS_TO&from=$SMS_FROM&text=BACKUP_ERRO ($NAME): $MSG is NOK" \
		'https://api.clickatell.com/http/sendmsg'
	    exit 1
    fi
}

# Test FROM
mount_point_is_ok $BKP_FROM_MOUNT_POINT "FROM"

# Test TO
mount_point_is_ok $BKP_TO_MOUNT_POINT "TO"

# Syncronization process
rsync -atb --delete --log-file="$LOG_PATH$LOG_FILE" --suffix=".$(date +"%Y%m%d_%H%M%S")" --backup-dir="$BKP_HISTORY_PATH" "$BKP_FROM_PATH" "$BKP_TO_PATH"
EXIT_CODE=$?

if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] EXIT CODE was: $EXIT_CODE" >> "$LOG_PATH$LOG_FILE"; fi

if [ "$EXIT_CODE" = "0" ] ; then
	MSG="rsync completed normally"
    if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG" >> "$LOG_PATH$LOG_FILE"; fi
    exit 0
elif [ "$EXIT_CODE" = "23" ]; then
	MSG="rsync completed with erros (exit code 23)"
    if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG" >> "$LOG_PATH$LOG_FILE"; fi
    curl --data "user=$SMS_USER&password=$SMS_PASS&api_id=$SMS_API_ID&to=351916411044&from=ImagUrbana&text=BACKUP_ERRO ($NAME): $MSG" \
		'https://api.clickatell.com/http/sendmsg'
    exit 0
else
	MSG="rsync failure"
    if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG" >> "$LOG_PATH$LOG_FILE"; fi
    curl --data "user=$SMS_USER&password=$SMS_PASS&api_id=$SMS_API_ID&to=351916411044&from=ImagUrbana&text=BACKUP_ERRO ($NAME): $MSG" \
		'https://api.clickatell.com/http/sendmsg'
    exit 1
fi
