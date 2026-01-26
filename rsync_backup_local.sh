#!/bin/bash

SOURCE="/mnt/003_ImagemUrbana/nas/"
# ATENÇÃO: Altere este caminho para o ponto de montagem do seu disco externo
DEST="/mnt/disco_externo_backup" 

# Pasta para onde vão os ficheiros apagados/alterados (semelhante ao --backup-dir do rclone)
# Nota: O caminho do backup-dir deve ser relativo ao destino ou absoluto. 
# Se for absoluto, deve estar dentro do mesmo filesystem para hardlinks funcionarem bem, 
# mas aqui será uma pasta normal.
BACKUP_DIR="$DEST/_ELIMINADOS/$(date +%Y-%m-%d_%H-%M)"

LOGFILE="/home/adb/Development/003_ImagemUrbana/backup-script/backup_rsync.log"

# Lista de pastas que DEVEM estar montadas na NAS (Origem)
REQUIRED_MOUNTS=("adb" "DISCO_IU" "DISCO_IU_NEW" "DISCO_IU_XXX" "Public" "software" "backup" "gestao_documental" "ifthen" "portal" "Concursos_Publicos")

# 1. Verifica se a NAS está montada (Origem)
for mount in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "${SOURCE}${mount}"; then
        echo "$(date): ERRO - A pasta de origem '${mount}' não está montada. Abortando." | tee -a "$LOGFILE"
        exit 1
    fi
done

# 2. Verifica se o disco externo está montado (Destino)
# Verifica se o diretório existe primeiro para evitar erros do mountpoint se não existir
if [ ! -d "$DEST" ] || ! mountpoint -q "$DEST"; then
   echo "$(date): ERRO - O disco de destino ($DEST) não está montado ou não existe. Abortando." | tee -a "$LOGFILE"
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
else
    echo "--- FALHA: $(date) - Ocorreram erros no rsync ---" >> "$LOGFILE"
fi
