# Backup Automation Scripts

This project contains scripts to automate file backups from a local NAS to a local HDD (using `rsync`) and to a cloud provider (Google Drive, using `rclone`). It also includes automated status notifications via Zulip.

## Scripts Overview

* `rsync_backup_local.sh`: Performs an incremental backup from the configured source to a local destination. Deleted or modified files are moved to a dated "deleted" directory rather than being permanently removed immediately.
* `rclone_backup_gdrive.sh`: Syncs files from the source to a configured cloud remote. Similar to the local backup, deleted files are moved to a specific backup directory on the remote.
* `notify_zulip.sh`: A helper script used by the backup scripts to send success or failure notifications to a Zulip stream.

## Prerequisites

Ensure the following tools are installed on your system:

* `rsync`
* `rclone`
* `curl` (for notifications)
* `mountpoint` (usually part of sysvinit-utils or util-linux)

## Setup

### 1. Configure the Environment

The scripts rely on a `.env` file for configuration. Create this file in the same directory as the scripts.

1. Create a file named `.env`:

    ```bash
    touch .env
    ```

2. Add the following content, adjusting the paths and credentials for your environment:

    ```dotenv
    # --- Source Configuration ---
    # The base path of your source files (e.g., your NAS mount)
    SOURCE_PATH="/mnt/nas/"

    # Space-separated list of subdirectories inside SOURCE_PATH that MUST be mounted.
    # The script will abort if any of these are missing.
    REQUIRED_MOUNTS_LIST="folder1 folder2 folder3"

    # --- Local Backup Configuration (Rsync) ---
    # A mount point to check before running rsync (extra safety to prevent writing to root partition)
    LOCAL_MOUNT_POINT="/mnt/HDD_Backup"

    # Destination for the current backup mirror
    RSYNC_DEST="/mnt/HDD_Backup/backup"

    # Where to store files that are deleted/changed from the source
    RSYNC_DELETED_BASE_DIR="/mnt/HDD_Backup/deleted"

    # Local log file location
    RSYNC_LOG_FILE="/mnt/HDD_Backup/logs/backup_rsync.log"

    # --- Cloud Backup Configuration (Rclone) ---
    # Rclone remote and path (e.g., RemoteName:Path)
    RCLONE_DEST="MyRemote:Backup_Main"

    # Remote path for deleted files
    RCLONE_BACKUP_DIR_BASE="MyRemote:Backup_Deleted"

    # Local log file location for rclone operations
    RCLONE_LOG_FILE="/mnt/HDD_Backup/logs/backup_rclone.log"

    # --- Notification Configuration (Zulip) ---
    ZULIP_URL="https://your-domain.zulipchat.com/api/v1/messages"
    ZULIP_BOT_EMAIL="your-bot-email@zulipchat.com"
    ZULIP_BOT_API_KEY="your-bot-api-key"
    ZULIP_STREAM="backups"
    ZULIP_TOPIC="status"
    ```

### 2. Make Scripts Executable

Run the following command in the script directory to ensure they can be executed:

```bash
chmod +x *.sh
```

## Configuration Details

* **REQUIRED_MOUNTS_LIST**: This is a critical safety feature. If you are backing up a mounted network drive that has sub-shares, listing them here ensures `rsync` doesn't see an empty directory and delete all your backups thinking the source files were removed.
* **Safe Deletion**: Both scripts use a `--backup-dir` strategy. If a file is deleted from the source, it is **not** immediately deleted from the destination. Instead, it is moved to a timestamped folder inside `RSYNC_DELETED_BASE_DIR` or `RCLONE_BACKUP_DIR_BASE`.

## Usage

You can run the scripts manually or schedule them via `cron`.

### Manual Run

To run the local backup:

```bash
./rsync_backup_local.sh
```

To run the cloud backup:

```bash
./rclone_backup_gdrive.sh
```

### Cron Example

To schedule automated backups, edit your crontab:

```bash
crontab -e
```

#### Option A: Full Backup (Recommended)

This is the **most efficient approach** for daily incremental backups. The script runs once, backing up all folders in a single operation with minimal overhead.

**Advantages:**

- Faster overall execution (single rsync initialization)
- Simpler configuration and maintenance
- Single log file per execution

**Disadvantages:**

- If it fails mid-execution, all folders after the failure point are skipped
- Harder to identify which specific folder caused an issue

```text
# Full backup daily at midnight
0 0 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh
```

#### Option B: Folder-by-Folder Backup

Run separate backup jobs for each folder. Use this approach when you need **granular control** or **isolated failure handling**.

**Advantages:**

* If one folder fails, others continue normally
* Separate logs and notifications per folder
* Easier to identify and retry failed folders
* Can prioritize critical folders

**Disadvantages:**

* Slower total execution (21× rsync initialization overhead)
* More complex crontab configuration
* More notification messages

**Schedule below is optimized by folder size** (larger folders get bigger time windows):

```text
# --- Individual Folder Backups (Local) ---
# Cronograma ajustado por tamanho: "Small" (10-15m), "Medium" (20-30m), "Large" (45m), "Massive" (2h-4h)
# Caminhos definidos para: /home/adb/Development/003_ImagemUrbana/scripts/backup/

# joc (248M)
0 0 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh joc

# pfg (5.1G)
5 0 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh pfg

# disco_iu_new (2.9T) - Janela de 4h
15 0 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh disco_iu_new

# backup (1.4T) - Janela de 2.5h
15 4 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh backup

# pedrooliv (58G)
45 6 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh pedrooliv

# ifthen (139G)
5 7 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh ifthen

# public (169G)
35 7 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh public

# disco_iu_xxx (7.7G)
10 8 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh disco_iu_xxx

# ams (229G)
20 8 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh ams

# crg (48G)
5 9 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh crg

# gestao_documental (7.6G)
20 9 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh gestao_documental

# fdv (192G)
30 9 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh fdv

# anabelarebelo (38G)
10 10 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh anabelarebelo

# disco_iu (1.2T) - Janela de 2.5h
25 10 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh disco_iu

# jfp (55G)
0 13 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh jfp

# software (48G)
20 13 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh software

# adb (204G)
35 13 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh adb

# danip (27G)
20 14 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh danip

# portal (917G) - Janela de 1.5h
35 14 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh portal

# sns (49G)
5 16 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh sns

# acessos (4K)
20 16 * * * /home/adb/Development/003_ImagemUrbana/scripts/backup/rsync_backup_local.sh acessos
```

## Logs & Notifications

* **Logs**: Logs are generated for every run.
  * Rsync logs: Defined by `RSYNC_LOG_FILE` (rotates with timestamp).
  * Rclone logs: Defined by `RCLONE_LOG_FILE` (rotates with timestamp).
* **Notifications**:
  * If the backup completes successfully, a **success** message is sent to the configured Zulip stream.
  * If the backup fails (mount missing, error code), an **error** message is sent to Zulip.
