# Backup Script Setup

This document explains how to configure the backup script to be executable from the command line.

## Setup Steps

### 1. Make the Script Executable

To make the `bkp.sh` script executable from the command line, you'll need to change the file permissions. Follow these steps:

1. **Open a terminal** in the directory where the `bkp.sh` script is located.

2. **Change the file permissions** to make it executable by running the following command:

    ```bash
    chmod +x bkp.sh
    ```

3. The script is now ready to be executed. You can run it directly from the terminal with:

    ```bash
    ./bkp.sh
    ```

### 2. (Optional) Add the Script to Your PATH

If you want to be able to run the script from any directory, you can add the directory containing the script to your `PATH`. To do this:

1. **Open your shell configuration file** (e.g., `~/.bashrc`, `~/.bash_profile`, or `~/.zshrc`).

2. **Add the following line to the end of the file**:

    ```bash
    export PATH=$PATH:/path/to/script/directory
    ```

    Replace `/path/to/script/directory` with the actual path to the directory where `bkp.sh` is located.

3. **Update your shell environment** to apply the changes:

    ```bash
    source ~/.bashrc
    ```

    or

    ```bash
    source ~/.bash_profile
    ```

4. You can now run the script from any directory by simply typing:

    ```bash
    bkp.sh
    ```

## Usage Example

To execute the `bkp.sh` script, type:

```bash
./bkp.sh
