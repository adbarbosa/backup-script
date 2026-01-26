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

To run the local backup every day at 02:00 AM and the cloud backup at 04:00 AM:

```bash
# Edit crontab
crontab -e

# Add lines:
0 2 * * * /home/user/path/to/rsync_backup_local.sh
0 4 * * * /home/user/path/to/rclone_backup_gdrive.sh
```

## Logs & Notifications

* **Logs**: Logs are generated for every run.
  * Rsync logs: Defined by `RSYNC_LOG_FILE` (rotates with timestamp).
  * Rclone logs: Defined by `RCLONE_LOG_FILE` (rotates with timestamp).
* **Notifications**:
  * If the backup completes successfully, a **success** message is sent to the configured Zulip stream.
  * If the backup fails (mount missing, error code), an **error** message is sent to Zulip.
