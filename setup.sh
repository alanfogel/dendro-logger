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

    sed -i "s|upload \$file /.*|upload \$file /${DROPBOX_FOLDER}/\"|" upload-to-dropbox_DENDRO.sh

    update_config "DROPBOX_FOLDER" "$DROPBOX_FOLDER"
    echo "Dropbox folder updated to /$DROPBOX_FOLDER"
}

function update_cron() {
    read -p "Enter upload hour (0–23) [Current: ${UPLOAD_HOUR:-not set}]: " input
    upload_hour="${input:-$UPLOAD_HOUR}"

    # Backup and filter crontab
    current_cron=$(mktemp)
    crontab -l > "$current_cron" 2>/dev/null || true

    # Remove previous logging & upload blocks with comment lines
    awk '
    BEGIN { skip = 0 }
    /# Reads .*dendrometer/ || /# Uploads data to Dropbox/ { skip = 1; next }
    /^[^#].*dendro_logging\.py/ || /upload-to-dropbox_DENDRO\.sh/ { if (skip) { skip = 0; next } }
    { print }
    ' "$current_cron" > "${current_cron}.tmp" && mv "${current_cron}.tmp" "$current_cron"

    # Append new jobs
    echo "# Reads data from dendrometers every 5 minutes" >> "$current_cron"
    echo "*/5 * * * * $SCRIPT_DIR/venv/bin/python3 $SCRIPT_DIR/dendro_logging.py" >> "$current_cron"
    echo "# Uploads data to Dropbox at $upload_hour:00" >> "$current_cron"
    echo "0 $upload_hour * * * bash $SCRIPT_DIR/upload-to-dropbox_DENDRO.sh" >> "$current_cron"

    # Install updated crontab
    crontab "$current_cron"
    rm "$current_cron"

    update_config "UPLOAD_HOUR" "$upload_hour"
    echo " Cron jobs updated. Upload will run at $upload_hour:00 each day."
}

function update_tree_mapping() {
    echo "Setting up dendrometer sensor configuration..."

    declare -A TREE_ID_MAP
    declare -A MICRON_SCALE

    for i in {0..3}; do
        prev_tree_id_var="TREE_ID_$i"
        prev_scale_var="MICRON_SCALE_$i"

        prev_tree_id="${!prev_tree_id_var}"
        prev_scale="${!prev_scale_var}"

        # Convert scale to label
        if [[ "$prev_scale" == "15000" ]]; then
            prev_scale_label="DC2"
        elif [[ "$prev_scale" == "25400" ]]; then
            prev_scale_label="DC3"
        else
            prev_scale_label="unknown"
        fi

        # Prompt for tree ID
        read -p "Channel $i - Enter Tree ID [Current: ${prev_tree_id:-not set}]: " input
        TREE_ID_MAP[$i]="${input:-$prev_tree_id}"
        update_config "$prev_tree_id_var" "${TREE_ID_MAP[$i]}"

        # Prompt for dendrometer type
        read -p "Channel $i - Enter dendrometer type (DC2 or DC3, or just 2 or 3) [Current: ${prev_scale_label}]: " dtype
        dtype=$(echo "$dtype" | tr '[:lower:]' '[:upper:]')  # normalize to uppercase

        if [[ -z "$dtype" ]]; then
            MICRON_SCALE[$i]="${prev_scale}"
        elif [[ "$dtype" == "2" || "$dtype" == "DC2" ]]; then
            MICRON_SCALE[$i]=15000
        elif [[ "$dtype" == "3" || "$dtype" == "DC3" ]]; then
            MICRON_SCALE[$i]=25400
        else
            echo "Unrecognized type '$dtype'. Using previous/default scale: ${prev_scale}"
            MICRON_SCALE[$i]="${prev_scale}"
        fi
        update_config "$prev_scale_var" "${MICRON_SCALE[$i]}"

        # Final confirmation
        final_label=$( [[ ${MICRON_SCALE[$i]} == 15000 ]] && echo DC2 || echo DC3 )
        echo "Updated: Tree ${TREE_ID_MAP[$i]} with $final_label"
    done


    # Build the code blocks as strings
    scale_block="MICRON_SCALE = {\n"
    id_block="TREE_ID_MAP = {\n"
    for i in {0..3}; do
        scale_block+="    $i: ${MICRON_SCALE[$i]},\n"
        id_block+="    $i: \"${TREE_ID_MAP[$i]}\",\n"
    done
    scale_block+="}"
    id_block+="}"

    today=$(date +"%B %d, %Y")

    # Replace placeholders using literal newlines (with awk)
    awk -v date="$today" \
        -v scale_block="$scale_block" \
        -v id_block="$id_block" '
    {
        gsub(/\{\{DATE\}\}/, date)
        if ($0 ~ /\{\{MICRON_SCALE\}\}/) {
            print scale_block
            next
        }
        if ($0 ~ /\{\{TREE_ID_MAP\}\}/) {
            print id_block
            next
        }
        print
    }' dendro_logging_template.py > dendro_logging.py

    echo "dendro_logging.py generated from template."
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