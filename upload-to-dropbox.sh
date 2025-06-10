#!/bin/bash
# --- Upload pictures ---
cd ~/Dropbox-Uploader
./dropbox_uploader.sh upload ~/dendro-pi-main/pictures/* /Dorval-7/ | grep "file exists with the same hash" > already_uploaded.txt

while IFS= read -r line; do
  FILENAME=$(echo "$line" | cut -d'"' -f 2)
  rm $FILENAME
done < already_uploaded.txt


# --- Upload dendrometer data ---
# Directories
LOG_DIR=~/dendro_logger
BACKUP_DIR=~/dendro_logger/DD_backup
DROPBOX_UPLOADER=~/Dropbox-Uploader/dropbox_uploader.sh

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Get today's date in YYYY-MM-DD format
TODAY=$(date +"%Y-%m-%d")

# Change to log directory
cd "$LOG_DIR"

# Loop through all channel files EXCEPT today's file
for file in channel_*.txt; do
    if [[ -f "$file" ]]; then
        # Extract the date from the filename
        FILE_DATE=$(echo "$file" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}")

        # Skip today's file (still being written to)
        if [[ "$FILE_DATE" == "$TODAY" ]]; then
            continue
        fi

        # Attempt to upload the file
        if "$DROPBOX_UPLOADER" upload "$file" /DD_Dorval-7/; then
            # If upload is successful, move to backup
            mv "$file" "$BACKUP_DIR/"
        else
            # If upload fails, print an error message (file stays in LOG_DIR for retrying)
            echo "Upload failed for $file"
        fi
    fi
done
