#!/bin/bash

# Carregar configurações do .env
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERRO: Ficheiro .env não encontrado em $SCRIPT_DIR"
    exit 1
fi

SOURCE="$SOURCE_PATH"
# ATENÇÃO: Altere este caminho no ficheiro .env se necessário
DEST="$RSYNC_DEST"

# Pasta para onde vão os ficheiros apagados/alterados
BACKUP_DIR="$DEST/_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)"

LOGFILE="$RSYNC_LOG_FILE"

# Converte a string do .env em array
IFS=' ' read -r -a REQUIRED_MOUNTS <<< "$REQUIRED_MOUNTS_LIST"

# 1. Verifica se a NAS está montada (Origem)
for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE}${mount}"; then
        MSG="ERRO - A pasta de origem '${mount}' não está montada. Abortando."
        echo "$(date): $MSG" | tee -a "$LOGFILE"
        "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local: $MSG"
        exit 1
    fi
done

# 2. Verifica se o disco externo está montado (Destino)
# Verifica se o diretório existe primeiro para evitar erros do mountpoint se não existir
if [ ! -d "$DEST" ] || ! mountpoint -q "$DEST"; then
   MSG="ERRO - O disco de destino ($DEST) não está montado ou não existe. Abortando."
   echo "$(date): $MSG" | tee -a "$LOGFILE"
   "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local: $MSG"
   exit 1
fi

echo "--- Início Backup Local (Rsync): $(date) ---" >> "$LOGFILE"

# Garante que a pasta de destino existe (embora a verificação de mountpoint já garanta que o ponto existe)
mkdir -p "$BACKUP_DIR"

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
    "$SCRIPT_DIR/notify_zulip.sh" "SUCCESS" "Rsync Local concluído com sucesso."
else
    echo "--- FALHA: $(date) - Ocorreram erros no rsync ---" >> "$LOGFILE"
    "$SCRIPT_DIR/notify_zulip.sh" "ERROR" "Rsync Local falhou. Verifique o log em $LOGFILE"
fi
