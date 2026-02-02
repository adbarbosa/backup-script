#!/bin/bash

# Define o PATH para incluir comandos comuns como curl
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Carrega ambiente se não estiver carregado (e variáveis necessárias não estiverem definidas)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -z "$ZULIP_URL" ] && [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

STATUS="$1" # SUCCESS ou ERROR
MESSAGE="$2"

# Se as configurações não estiverem presentes, ignora (ou loga erro para stdout)
if [ -z "$ZULIP_URL" ] || [ -z "$ZULIP_BOT_EMAIL" ] || [ -z "$ZULIP_BOT_API_KEY" ]; then
    echo "AVISO: Configurações do Zulip em falta no .env. Notificação não enviada."
    exit 0
fi

if [ "$STATUS" == "SUCCESS" ]; then
    ICON=":check_mark:"
    TITLE="Backup Sucesso"
elif [ "$STATUS" == "START" ]; then
    ICON=":rocket:"
    TITLE="Backup Iniciado"
elif [ "$STATUS" == "TEST" ]; then
    ICON=":loudspeaker:"
    TITLE="Teste de Notificação"
else
    ICON=":stop_sign:"
    TITLE="Backup Falha"
fi

# Constrói o conteúdo. 
# Nota: Zulip usa Markdown.
CONTENT="$ICON **$TITLE**
$MESSAGE"

# Envia a notificação
curl -X POST "$ZULIP_URL" \
    -u "$ZULIP_BOT_EMAIL:$ZULIP_BOT_API_KEY" \
    --data-urlencode "type=stream" \
    --data-urlencode "to=$ZULIP_STREAM" \
    --data-urlencode "topic=$ZULIP_TOPIC" \
    --data-urlencode "content=$CONTENT" \
    --silent --output /dev/null

# Não falha o script principal se a notificação falhar
exit 0
