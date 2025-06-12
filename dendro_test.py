# Date: June 12, 2025
# This script continuously reads dendrometer data from 4 channels and displays the output in-place.

import time
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

tree_ids = config.get('TREE_IDS', '').strip('()').split()
micron_scales = config.get('MICRON_SCALES', '').strip('()').split()

TREE_ID_MAP = {i: tree_ids[i] for i in range(4)}
MICRON_SCALE = {i: int(micron_scales[i]) for i in range(4)}

# Initialize I2C and ADC
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c)
ads.gain = 1

channels = {
    0: AnalogIn(ads, ADS.P0),
    1: AnalogIn(ads, ADS.P1),
    2: AnalogIn(ads, ADS.P2),
    3: AnalogIn(ads, ADS.P3)
}

def live_monitor(samples=10, delay=0.1, refresh_interval=1.0):
    try:
        while True:
            output_lines = []

            for chan_num, chan in channels.items():
                readings = []
                for _ in range(samples):
                    try:
                        voltage = chan.voltage
                        readings.append(voltage)
                        time.sleep(delay / samples)
                    except Exception as e:
                        output_lines.append(f"Channel {chan_num} read error: {e}")
                        break

                if not readings:
                    output_lines.append(f"Channel {chan_num} failed to collect valid samples.")
                    continue

                avg_voltage = sum(readings) / len(readings)
                microns = avg_voltage / 3.3 * MICRON_SCALE[chan_num]
                hardware_ch = chan_num + 1
                tree_id = TREE_ID_MAP.get(chan_num, f"ch{hardware_ch}")

                output_lines.append(
                    f"Tree {tree_id} Ch{hardware_ch}: {microns:.2f} µm, {avg_voltage:.4f} V (avg of {len(readings)} samples)"
                )

            print("\033[2J\033[H", end="")  # Clear screen and move to top
            print("------------------------------------------------------")
            print("Live Dendrometer Monitor - Press Ctrl+C to stop")
            print("------------------------------------------------------")
            print("Showing averaged micrometer displacement and voltage for each channel.\n")
            print("\n".join(output_lines))
            time.sleep(refresh_interval)

    except KeyboardInterrupt:
        print("\nMonitoring stopped.")

if __name__ == "__main__":
    live_monitor()
