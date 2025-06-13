# 🌲 Dendrometer Pi Logging System
This project sets up a Raspberry Pi to performs the following:
- Reads millivolt values from 4 dendrometer channels using the ADS1115 ADC
- Converts raw values into microns based on dendrometer type (DC2 = 15μm/mV, DC3 = 25.4μm/mV)
- Saves a timestamped `.csv` log file with daily measurements
- Uploads the `.csv` files nightly to Dropbox using Dropbox-Uploader
- Allows easy configuration of:
  - Tree IDs and dendrometer types
  - Upload time (staggered across devices)
  - Dropbox folder path (based on Pi hostname by default)


The default behaviour of this system is to read the data off of 4 dendrometers every ___ minutes, and upload the .csv each night to a Dropbox folder named after the Pi's hostname (e.g., `Dorval-8`).

## Prerequisites
- Make sure you have followed the initial setup instructions from: https://github.com/alanfogel/dendro-pi-main

- Required hardware:
  - Raspberry Pi (any model with header pins)
  - [ADS1115, 4 Channel, Analog-to-Digital Converter](https://www.amazon.ca/SHILLEHTEK-Pre-Soldered-Converter-Programmable-Amplifier/dp/B0BXWJFCVJ?crid=1CJPAOBIIR80S&dib=eyJ2IjoiMSJ9.-aNjWfj4Qr19a01sv7QCggrRyNp5npRY6TFrwslaoLfHGGvvQfMXEr_H6reD-_2YF5ZDlJXgSnJ4DeqqEoPutoKFToyQba1FtvKSEwhYBO-OzCcA4Jkw14FLoL0Z5t1kbQOelaFC1N_06X2y-Y3qAFzYswU18eXQ1oqlKVdepoHYyNc42O6cVdXAQewmvQNJY1nirrKtoYRS1e-XxCtozQa5ZpkCZ0vnu0pOw41gM0Xqj0hEGqJIDQkp8cXSSPXQBK9bLTiBQWOJ2qAyMBfDiqdeA5dVYNtOM31thIAZroY.Goudm8lI-JTL3kyv9SUTtiFwdPjqmX0uuDdqsH9FFHY&dib_tag=se&keywords=I2C+Sensor+adc&qid=1718218426&sprefix=i2c+sensor+adc%2Caps%2C118&sr=8-7)
  - [DC Circumference Dendrometer](https://ecomatik.de/en/products/growth-and-plant-water-status-dendrometer/circumference-dc/) (We use DC2 and DC3 dendrometers)

---
## 🔌 Physical Setup and Wiring

This section describes how to wire the dendrometers, ADC (ADS1115), and Raspberry Pi for proper data acquisition.
### 1. Components Overview
- **Dendrometers:** Provide analog voltage output corresponding to circumference changes.
- **ADS1115 ADC:** 4-channel analog-to-digital converter wi- I2C interface.
- **Raspberry Pi:** Supplies reference voltage (Vref), grou- (GND), and communicates with ADC via I2C pins.

### 2. Wiring Connections
| Dendrometer 3 wires          | ADC Pin                |    Notes                        |
| ------------------------ | -------------------- | ----------------------------- |
| Vref (Reference Voltage) | VDD (Power)            | Power supply from Pi 3.3V       |
| Analog Output            | A0..A3 (Analog Inputs) | One dendrometer per ADC channel |
| Ground (GND)             | GND                    | Common ground with Pi and ADC   |

| ADC Pin | Pi Pin (Header)      | Notes                                |
| ------- | -------------------- | ------------------------------------ |
| VDD     | 3.3V (Pin 1)         | Power supply from Pi                 |
| GND     | GND (Pin 6)          | Common ground                        |
| SCL     | SCL (Pin 5)          | I2C clock line                       |
| SDA     | SDA (Pin 3)          | I2C data line                        |

| ADC Analog Inputs    | Dendrometer Number      |
| -------------------- | -------------------- | 
| A0   | Dendrometer  1 |
| A1   | Dendrometer  2 |
| A2   | Dendrometer  3 |
| A3   | Dendrometer  4 |

## 3. Important Notes

- Common Ground: All grounds from dendrometers, ADC, and Pi should be connected together to ensure accurate analog readings.
- Power Supply: Use the Pi's 3.3V pin for Vref and ADC power; do NOT use 5V as the ADC and Pi I2C pins expect 3.3V logic levels.
- I2C Pins: Use physical header pins 3 (SDA) and 5 (SCL) on the Pi for - ADC communication.


---
## 🚀 Quick Setup (Automated)

Use the included setup.sh script to handle installation and configuration:
```bash
cd ~/dendro-pi-main  # Must already exist
git clone https://github.com/alanfogel/dendro-logger.git
```

Then run the setup script:
```bash
cd dendro-logger
chmod +x setup.sh
./setup.sh
```

First you will be prompted to select what you want to do:
- **"Full setup (first-time install)"** (this will install all dependencies, set up the virtual environment, and configure cron jobs, and then take you through the rest of the setup)
- **"Update Dropbox folder name"**
- **"Update upload time (staggered cron)"**
- **"Update dendrometer types & tree IDs"**
- **"Exit"**

The full setup will take a while, you may need to awnser "y" when promted.

If you prefer your data to be saved as a `.csv` file instead of a `.txt` file, you can change the cron job to run the `dendro_logging_csv.py` script instead of `dendro_logging.py` by editing the cron job file:
```bash
crontab -e
```
Then change the line:
```bash
*/5 * * * * /home/madlab/dendro-pi-main/dendro-logger/venv/bin/python3 /home/madlab/dendro-pi-main/dendro-logger/dendro_logging.py 
```
to:
```bash
*/5 * * * * /home/madlab/dendro-pi-main/dendro-logger/venv/bin/python3 /home/madlab/dendro-pi-main/dendro-logger/dendro_logging_csv.py
```
---
## 🧪 Verify Setup
### One line to read live values back from dendrometers at 1s intervals (Does not save to file)
- Good for testing if the dendrometers are connected and working properly.
```bash
/home/madlab/dendro-pi-main/dendro-logger/venv/bin/python3 /home/madlab/dendro-pi-main/dendro-logger/dendro_test.py
```

### Regular full setup verification to test reading, saving, and uploading
1. Run `source venv/bin/activate` to activate Python environment
2. Run `python3 dendro_logging.py` manually and check for output in `data/`
3. Run `bash upload-to-dropbox_DENDRO.sh` to confirm Dropbox sync

---
To change settings later, simply re-run:

```bash
./setup.sh
```

Then choose:
- `Option 2` to rename the Dropbox folder
- `Option 3` to change the cron upload time
- `Option 4` to update tree IDs or dendrometer types
---

## ⚙️ Manual Setup:
1. **Clone the project** ***(eventually this repo):***
````bash
cd dendro-pi-main
git clone https://github.com/alanfogel/dendro_logger.git
cd dendro_logger
````

2. **Make sure the Pi is up to date and Pip is installed:**
```bash
sudo apt update
sudo apt-get install python3-pip
```

3. **Create and Activate Virtual Environment:**
```bash
python3 -m venv venv
source venv/bin/activate
```

4. **Install necessary libraries:**
```bash
sudo apt-get install libopenblas-dev
pip install adafruit-circuitpython-busdevice adafruit-circuitpython-ads1x15 numpy
pip install RPi.GPIO
```

5. **Enable I2C in Raspberry Pi Config**
```bash
sudo raspi-config
```
**Interface Options → I2C → Enable**

6. **Add new cron jobs:**
```bash
crontab -e
```
Add the following lines to the end of the file:
```ruby
# Sample each channel every 5 minutes
*/5 * * * * /home/madlab/dendro-pi-main/dendro-logger/venv/bin/python3 /home/madlab/dendro-pi-main/dendro-logger/dendro_logging.py 

# Upload dendrometer data to Dropbox every day at 2am
0 2 * * * bash /home/madlab/dendro-pi-main/dendro-logger/upload-to-dropbox_DENDRO.sh
````



