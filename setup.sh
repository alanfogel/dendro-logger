#!/bin/bash
set -e

echo "Updating system..."
sudo apt update
sudo apt install -y python3-pip libopenblas-dev

echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Installing Python dependencies..."
pip install adafruit-circuitpython-busdevice adafruit-circuitpython-ads1x15 numpy RPi.GPIO

echo "Enabling I2C interface..."
sudo raspi-config nonint do_i2c 0

echo "Setting up cron jobs..."
CURRENT_CRON=$(mktemp)
crontab -l > "$CURRENT_CRON" 2>/dev/null || true

# Add each line from fragment only if it doesn't already exist
SCRIPT_DIR="$(pwd)"

while read -r line; do
  # Inject the absolute path into each cron line
  parsed_line=$(echo "$line" | sed "s|\$SCRIPT_DIR|$SCRIPT_DIR|g")
  if ! grep -Fq "$parsed_line" "$CURRENT_CRON"; then
    echo "$parsed_line" >> "$CURRENT_CRON"
  fi
done < crontab-fragment.txt


crontab "$CURRENT_CRON"
rm "$CURRENT_CRON"

echo "Setup complete!"
