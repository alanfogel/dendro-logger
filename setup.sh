#!/bin/bash
set -e

CONFIG_FILE="dendro_config.env"
SCRIPT_DIR="$(pwd)"

# Load saved config if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

function main_menu() {
    echo ""
    echo "What would you like to do?"
    select option in \
        "Full setup (first-time install)" \
        "Update Dropbox folder name" \
        "Update upload time (staggered cron)" \
        "Update dendrometer types & tree IDs" \
        "Exit"
    do
        case $REPLY in
            1) full_setup; break ;;
            2) update_dropbox; break ;;
            3) update_cron; break ;;
            4) update_tree_mapping; break ;;
            5) echo "Exiting."; exit 0 ;;
            *) echo "Invalid choice, please enter 1–5." ;;
        esac
    done
}

function full_setup() {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y python3-pip libopenblas-dev

    echo "Creating virtual environment... (This may take a while)"
    python3 -m venv venv
    source venv/bin/activate

    echo "Installing Python packages... (This may take a while)"
    python -m pip install --upgrade pip
    sudo apt install libopenblas0-pthread libgfortran5
    pip install adafruit-circuitpython-busdevice adafruit-circuitpython-ads1x15
    pip install --verbose numpy==2.2.4 # Using the latest piwheel version to speedup installation
    pip install RPi.GPIO

    echo "Enabling I2C interface..."
    sudo raspi-config nonint do_i2c 0

    update_dropbox
    update_cron
    update_tree_mapping

    echo "Full setup complete!"
}

function update_dropbox() {
    read -p "Enter Dropbox folder name (e.g., DD_Dorval-2) [Current: ${DROPBOX_FOLDER:-not set}]: " input
    DROPBOX_FOLDER="${input:-$DROPBOX_FOLDER}"
    update_config "DROPBOX_FOLDER" "$DROPBOX_FOLDER"
    echo "Dropbox folder updated to /$DROPBOX_FOLDER"
}

function update_cron() {
    CONFIG_FILE="$SCRIPT_DIR/dendro_config.env"
    source "$CONFIG_FILE"

    read -p "Enter upload hour (0–23) [Current: ${UPLOAD_HOUR:-not set}]: " input
    upload_hour="${input:-$UPLOAD_HOUR}"

    # Fallback to 2 AM if nothing was set previously
    if [[ -z "$upload_hour" ]]; then
        upload_hour=2
    fi

    # Backup current crontab
    current_cron=$(mktemp)
    crontab -l > "$current_cron" 2>/dev/null || true

    # Remove any old dendro_logger-related entries + their comment lines
    awk '
    BEGIN { skip = 0 }
    /# Reads data from dendrometers/ || /# Uploads data to Dropbox/ { skip = 1; next }
    /^[^#].*dendro_logging\.py/ || /upload-to-dropbox_DENDRO\.sh/ {
        if (skip) { skip = 0; next }
    }
    { print }
    ' "$current_cron" > "${current_cron}.tmp" && mv "${current_cron}.tmp" "$current_cron"

    # Append new cron jobs
    echo "# Reads data from dendrometers every 5 minutes" >> "$current_cron"
    echo "*/5 * * * * $SCRIPT_DIR/venv/bin/python3 $SCRIPT_DIR/dendro_logging.py" >> "$current_cron"
    echo "# Uploads data to Dropbox at $upload_hour:00" >> "$current_cron"
    echo "0 $upload_hour * * * bash $SCRIPT_DIR/upload-to-dropbox_DENDRO.sh" >> "$current_cron"

    # Install new crontab and cleanup
    crontab "$current_cron"
    rm "$current_cron"

    # Save updated value to config
    update_config "UPLOAD_HOUR" "$upload_hour"

    echo "Cron jobs updated. Upload will run at $upload_hour:00 each day."
}


function update_tree_mapping() {
    echo "Setting up dendrometer sensor configuration..."

    TREE_IDS=()
    MICRON_SCALES=()

    for i in {0..3}; do
        prev_id_var="TREE_ID_$i"
        prev_scale_var="MICRON_SCALE_$i"

        prev_tree_id="${!prev_id_var}"
        prev_scale="${!prev_scale_var}"

        # Prompt for Tree ID
        read -p "Channel $i - Enter Tree ID [Current: ${prev_tree_id:-not set}]: " input
        TREE_IDS+=("${input:-$prev_tree_id}")

        # Prompt for dendrometer type
        read -p "Channel $i - Enter dendrometer type (DC2 or DC3) [Current: ${prev_scale:-not set}]: " dtype
        dtype=$(echo "$dtype" | tr '[:lower:]' '[:upper:]')
        case "$dtype" in
            "" ) MICRON_SCALES+=("$prev_scale") ;;
            "2"|"DC2") MICRON_SCALES+=(15000) ;;
            "3"|"DC3") MICRON_SCALES+=(25400) ;;
            * ) echo "Unrecognized type '$dtype'. Using previous/default scale."; MICRON_SCALES+=("$prev_scale") ;;
        esac
    done

    # Join arrays into space-separated strings
    id_str="${TREE_IDS[*]}"
    scale_str="${MICRON_SCALES[*]}"

    update_config "TREE_IDS" "(${id_str})"
    update_config "MICRON_SCALES" "(${scale_str})"

    echo "Tree mapping updated and saved to $CONFIG_FILE."
}


update_config() {
    local key="$1"
    local value="$2"

    # If key exists, replace it. Else, add it.
    if grep -q "^$key=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
    else
        echo "$key=$value" >> "$CONFIG_FILE"
    fi
}


# ---- START HERE ----
main_menu