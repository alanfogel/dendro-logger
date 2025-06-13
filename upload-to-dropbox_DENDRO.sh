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

# --- Upload dendrometer data .txt ---
# Change to the directory where data files are stored
cd "$LOG_DIR" || exit 1

# Loop through all channel files EXCEPT today's file
for file in ???_ch[1-4]_*.txt; do # Channel files named like 001_ch1_2023-10-01.txt
#    echo "Calling uploader: $DROPBOX_UPLOADER upload $file /DD_Dorval-2/"
    if [[ -f "$file" ]]; then
        # Extract the date from the filename
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")

        # Skip today's file (still being written to)
        if [[ "$FILE_DATE" == "$TODAY" ]]; then
            echo "Skipped $file: it is today's file ($TODAY), may still be written to"
            continue
        fi

        # Attempt to upload $file
        if "$DROPBOX_UPLOADER" upload "$file" "/$DROPBOX_FOLDER/"; then
            echo "Uploaded: $file"
            # If upload $file /$DROPBOX_FOLDER/ was successful, move it to the backup directory
            mv "$file" "$BACKUP_DIR/"
        else
            echo "Upload failed for $file"
        fi
    fi
done

# --- Upload dendrometer data .csv ---
for file in *.csv; do # Channel files named like DD_Dorval-2_2023-10-01.csv
    if [[ -f "$file" ]]; then
        # Extract the date from the filename
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")

        # Skip today's file (still being written to)
        if [[ "$FILE_DATE" == "$TODAY" ]]; then
            echo "Skipped $file: it is today's file ($TODAY), may still be written to"
            continue
        fi

        # Attempt to upload $file
        if "$DROPBOX_UPLOADER" upload "$file" "/$DROPBOX_FOLDER/"; then
            echo "Uploaded: $file"
            # If upload $file /$DROPBOX_FOLDER/ was successful, move it to the backup directory
            mv "$file" "$BACKUP_DIR/"
        else
            echo "Upload failed for $file"
        fi
    fi
done
