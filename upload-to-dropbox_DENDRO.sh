#!/bin/bash

# --- Upload dendrometer data ---
# Directories
LOG_DIR="$HOME/dendro-pi-main/dendro-logger/data"
BACKUP_DIR="$LOG_DIR/DD_backup"
DROPBOX_UPLOADER="$HOME/dendro-pi-main/Dropbox-Uploader/dropbox_uploader.sh"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Get today's date in YYYY-MM-DD format
TODAY=$(date +"%Y-%m-%d")

# Change to the directory where data files are stored
cd "$LOG_DIR" || {
    echo "Failed to cd into $LOG_DIR"
    exit 1
}

# Loop through all channel files EXCEPT today's file
for file in ???_ch[1-4]_*.txt; do # Channel files named like 001_ch1_2023-10-01.txt
#    echo "Calling uploader: $DROPBOX_UPLOADER upload $file /DD_Dorval-2/"
    if [[ -f "$file" ]]; then
        # Extract the date from the filename
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")

        # Skip today's file (still being written to)
        if [[ "$FILE_DATE" == "$TODAY" ]]; then
            echo "Skipped $file : Because it is currently $TODAY and may still be written to"
            continue
        fi

        # Attempt to upload $file /DD_Dorval-2/"
        if "$DROPBOX_UPLOADER" upload "$file" "/DD_Dorval-2/"; then
            echo "Upload succeeded: $file"
            # If upload $file /DD_Dorval-2/"
            mv "$file" "$BACKUP_DIR/"
        else
            # If upload $file /DD_Dorval-2/"
            echo "Upload failed for $file"
        fi
    fi
done