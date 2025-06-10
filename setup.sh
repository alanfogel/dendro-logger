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
    echo "🛠️ What would you like to do?"
    select option in \
        "1) Full setup (first-time install)" \
        "2) Update Dropbox folder name" \
        "3) Update upload time (staggered cron)" \
        "4) Update dendrometer types & tree IDs" \
        "5) Exit"
    do
        case $REPLY in
            1) full_setup; break ;;
            2) update_dropbox; break ;;
            3) update_cron; break ;;
            4) update_tree_mapping; break ;;
            5) echo "❌ Exiting."; exit 0 ;;
            *) echo "❗ Invalid choice, please enter 1–5." ;;
        esac
    done
}

function full_setup() {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y python3-pip libopenblas-dev

    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate

    echo "Installing Python packages..."
    pip install adafruit-circuitpython-busdevice adafruit-circuitpython-ads1x15 numpy RPi.GPIO

    echo "Enabling I2C interface..."
    sudo raspi-config nonint do_i2c 0

    update_dropbox
    update_cron
    update_tree_mapping

    echo "Full setup complete!"
}

function update_dropbox() {
    read -p "Enter Dropbox folder name (e.g., DD_Dorval-7): " dropbox_folder
    sed -i "s|upload .*|upload \$file /${dropbox_folder}/; then|" upload-to-dropbox_DENDRO.sh
    echo "DROPBOX_FOLDER=$dropbox_folder" > "$CONFIG_FILE"
    echo "Dropbox folder updated to /$dropbox_folder"
}

function update_cron() {
    read -p "Enter upload hour (0–23): " upload_hour
    current_cron=$(mktemp)
    crontab -l > "$current_cron" 2>/dev/null || true

    # Remove existing lines with dendro_logging.py or upload script
    sed -i "/dendro_logging.py/d" "$current_cron"
    sed -i "/upload-to-dropbox_DENDRO.sh/d" "$current_cron"

    echo "*/5 * * * * $SCRIPT_DIR/venv/bin/python3 $SCRIPT_DIR/dendro_logging.py" >> "$current_cron"
    echo "$upload_hour 2 * * * $SCRIPT_DIR/venv/bin/python3 $SCRIPT_DIR/upload-to-dropbox_DENDRO.sh" >> "$current_cron"

    crontab "$current_cron"
    rm "$current_cron"

    echo "UPLOAD_HOUR=$upload_hour" >> "$CONFIG_FILE"
    echo "Cron jobs set. Upload will run at $upload_hour:00 each day."
}

function update_tree_mapping() {
    echo "📋 Setting up dendrometer sensor configuration..."

    declare -A TREE_ID_MAP
    declare -A MICRON_SCALE

    for i in {0..3}; do
        read -p "Channel $i - Enter Tree ID: " tree_id
        TREE_ID_MAP[$i]=$tree_id

        read -p "Channel $i - Enter dendrometer type (DC2 or DC3): " dtype
        if [[ "$dtype" == "DC2" ]]; then
            MICRON_SCALE[$i]=15000
        else
            MICRON_SCALE[$i]=25400
        fi
    done

    # Build the code blocks as strings
    scale_block="MICRON_SCALE = {\n"
    id_block="TREE_ID_MAP = {\n"
    for i in {0..3}; do
        scale_block+="    $i: ${MICRON_SCALE[$i]},\n"
        id_block+="    $i: \"${TREE_ID_MAP[$i]}\",\n"
    done
    scale_block+="}\n"
    id_block+="}\n"

    # Escape for sed substitution
    esc_scale_block=$(printf "%s" "$scale_block" | sed 's/[&/\]/\\&/g')
    esc_id_block=$(printf "%s" "$id_block" | sed 's/[&/\]/\\&/g')
    today=$(date +"%B %d, %Y")

    sed -e "s|{{MICRON_SCALE}}|$esc_scale_block|" \
        -e "s|{{TREE_ID_MAP}}|$esc_id_block|" \
        -e "s|{{DATE}}|$today|" \
        dendro_logging_template.py > dendro_logging.py

    echo "dendro_logging.py generated from template."
}

# ---- START HERE ----
main_menu
