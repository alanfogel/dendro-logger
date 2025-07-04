# Date: June 13, 2025
# This script reads dendrometer data from 4 channels, processes it, and saves the results to .csv

import datetime
import time
import csv
import os
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn

# Load config from .env file
def load_env_config(path):
    config = {}
    with open(path, 'r') as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                k, v = line.strip().split('=', 1)
                config[k] = v
    return config

config = load_env_config(os.path.expanduser('~/dendro-pi-main/dendro-logger/dendro_config.env'))

# Extract tree IDs and micron scales from the config
tree_ids = config.get('TREE_IDS', '').strip('()').split()
micron_scales = config.get('MICRON_SCALES', '').strip('()').split()
dropbox_folder = config.get('DROPBOX_FOLDER', 'dendro_data').strip('()') # Default to 'dendro_data' if not set

# Save the tree IDs and micron scales as integers
TREE_ID_MAP = {i: tree_ids[i] for i in range(4)}
MICRON_SCALE = {i: int(micron_scales[i]) for i in range(4)}

# Initialize I2C communication
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c)
ads.gain = 1  # ±4.096V range, for 3.3V signals

# Initialize all 4 ADC channels
channels = {
    0: AnalogIn(ads, ADS.P0),
    1: AnalogIn(ads, ADS.P1),
    2: AnalogIn(ads, ADS.P2),
    3: AnalogIn(ads, ADS.P3)
}

# Sample each channel N times, average, and log to file
def read_and_log(samples=10, delay=0.1):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    datestamp = datetime.date.today().strftime("%Y-%m-%d")

    file_path = f"/home/madlab/dendro-pi-main/dendro-logger/data/{dropbox_folder}_{datestamp}.csv"

    micron_values = []

    for chan_num in sorted(channels.keys()):
        chan = channels[chan_num]
        readings = []
        for _ in range(samples):
            try:
                voltage = chan.voltage
                readings.append(voltage)
            except Exception as e:
                print(f"Channel {chan_num} read error: {e}")
                continue

            if not readings:
                print(f"Channel {chan_num} failed to collect valid samples.")
                micron_values.append('NaN')
                continue

        avg_voltage = sum(readings) / len(readings)
        microns = avg_voltage / 3.3 * MICRON_SCALE[chan_num]
        microns = max(0.0, microns)  # Prevent negative values
        micron_values.append(microns)

        # Convert 0-based software channel number to 1-based hardware label
        hardware_ch = chan_num + 1
        tree_id = TREE_ID_MAP.get(chan_num, f"ch{hardware_ch}")  # fallback to channel if no tree ID
        print(f"Tree {tree_id} Ch{hardware_ch}: {microns:.2f} µm, {avg_voltage:.4f} V (avg of {len(readings)} samples)")

    # Save to CSV
    # If it exists, append to the file; if not, create it with headers and then append
    file_exists = os.path.exists(file_path)
    with open(file_path, "a", newline="") as f:
        writer = csv.writer(f)

        if not file_exists:
            header = ["Timestamp"] + [f"Ch{ch+1} µm (Tree: {TREE_ID_MAP.get(ch, f'ch{ch+1}')})" for ch in channels.keys()]
            writer.writerow(header)

        writer.writerow([timestamp] + micron_values)
        
if __name__ == "__main__":
    read_and_log()










