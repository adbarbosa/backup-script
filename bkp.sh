#!/bin/bash

# Estado da informação de debug
DEBUG=true
echo "Debug is $DEBUG"

# Verifica se o jq está instalado
if ! command -v jq &> /dev/null
then
	MSG="A ferramenta jq não está instalada. Por favor, instale-a primeiro."
    echo "$MSG"
	if [ "$DEBUG" = true ] ; then echo "$(date +"%Y/%m/%d %H:%M:%S") [$NAME] $MSG" >> "$LOG_PATH$LOG_FILE"; fi
    exit 1
fi

# Ler os valores do ficheiro JSON
SMS_USER=$(jq -r '.SMS.USER' env.json)
SMS_PASS=$(jq -r '.SMS.PASS' env.json)
SMS_API_ID=$(jq -r '.SMS.API_ID' env.json)
SMS_TO=$(jq -r '.SMS.TO' env.json)
SMS_FROM=$(jq -r '.SMS.FROM' env.json)

LOG_PATH=$(jq -r '.LOG.PATH' env.json)
LOG_FILE="log_adb_$(date +"%Y%m%d_%H%M%S").log"

NAME="adb"

BKP_FROM_MOUNT_POINT="/mnt/nas/adb"
BKP_FROM_PATH="${BKP_FROM_MOUNT_POINT}/"

BKP_TO_MOUNT_POINT="/mnt/bkp_drive"
BKP_TO_PATH="${BKP_TO_MOUNT_POINT}/adb/"

BKP_HISTORY_PATH=$(jq -r '.BACKUP.HISTORY_PATH' env.json)

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
