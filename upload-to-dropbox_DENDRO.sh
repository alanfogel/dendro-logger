#!/bin/bash

# Load config
source "$HOME/dendro-pi-main/dendro-logger/dendro_config.env"
DROPBOX_FOLDER="${DROPBOX_FOLDER:-DD_Default}"
DROPBOX_UPLOADER="$HOME/dendro-pi-main/Dropbox-Uploader/dropbox_uploader.sh"
LOG_DIR="$HOME/dendro-pi-main/dendro-logger/data"
BACKUP_DIR="$LOG_DIR/DD_backup"

# Get today's date in YYYY-MM-DD format
TODAY=$(date +"%Y-%m-%d")

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

cd "$LOG_DIR" || exit 1

# --- Upload .txt files ---
for file in ???_ch[1-4]_*.txt; do
    if [[ -f "$file" ]]; then
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        echo "Uploading $file..."

        if "$DROPBOX_UPLOADER" upload "$file" "/$DROPBOX_FOLDER/"; then
            echo "Uploaded: $file"
            if [[ "$FILE_DATE" != "$TODAY" ]]; then
                mv "$file" "$BACKUP_DIR/"
                echo "Moved to backup: $file"
            else
                echo "File is from today, not moving: $file"
            fi
        else
            echo "Upload failed for $file"
        fi
    fi
done

# --- Upload .csv files ---
for file in *.csv; do
    if [[ -f "$file" ]]; then
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        echo "Uploading $file..."

        if "$DROPBOX_UPLOADER" upload "$file" "/$DROPBOX_FOLDER/"; then
            echo "Uploaded: $file"
            if [[ "$FILE_DATE" != "$TODAY" ]]; then
                mv "$file" "$BACKUP_DIR/"
                echo "Moved to backup: $file"
            else
                echo "File is from today, not moving: $file"
            fi
        else
            echo "Upload failed for $file"
        fi
    fi
done
