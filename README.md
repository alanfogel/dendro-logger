# 🌲 Dendrometer Pi Logging System
This project sets up a Raspberry Pi to read data off of dendrometers, save it to a .csv file, and upload it to Dropbox.

The default behaviour of this system is to read the data off of 4 dendrometers every ___ minutes, and upload the .csv each night to a Dropbox folder named after the Pi's hostname (e.g., `Dorval-8`).

## Prerequisites
- Make sure you have followed the initial setup instructions from: https://github.com/alanfogel/dendro-pi-main

- Required hardware:
  - Raspberry Pi (any model with header pins)
  - [ADS1115, 4 Channel, Analog-to-Digital Converter](https://www.amazon.ca/SHILLEHTEK-Pre-Soldered-Converter-Programmable-Amplifier/dp/B0BXWJFCVJ?crid=1CJPAOBIIR80S&dib=eyJ2IjoiMSJ9.-aNjWfj4Qr19a01sv7QCggrRyNp5npRY6TFrwslaoLfHGGvvQfMXEr_H6reD-_2YF5ZDlJXgSnJ4DeqqEoPutoKFToyQba1FtvKSEwhYBO-OzCcA4Jkw14FLoL0Z5t1kbQOelaFC1N_06X2y-Y3qAFzYswU18eXQ1oqlKVdepoHYyNc42O6cVdXAQewmvQNJY1nirrKtoYRS1e-XxCtozQa5ZpkCZ0vnu0pOw41gM0Xqj0hEGqJIDQkp8cXSSPXQBK9bLTiBQWOJ2qAyMBfDiqdeA5dVYNtOM31thIAZroY.Goudm8lI-JTL3kyv9SUTtiFwdPjqmX0uuDdqsH9FFHY&dib_tag=se&keywords=I2C+Sensor+adc&qid=1718218426&sprefix=i2c+sensor+adc%2Caps%2C118&sr=8-7)
  - [DC Circumference Dendrometer](https://ecomatik.de/en/products/growth-and-plant-water-status-dendrometer/circumference-dc/) (We use DC2 and DC3 dendrometers)

---
## Quick Setup (Automated)

Use the included setup.sh script to handle installation and configuration:
```bash
cd ~/dendro-pi-main  # Must already exist
git clone https://github.com/alanfogel/dendro-logger.git
cd dendro-logger
chmod +x setup.sh
./setup.sh
```
ℹ️ The script installs dependencies, sets up a virtual environment, enables I2C, and configures cron jobs.

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
````

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
```
# Sample each channel every 5 minutes
*/5 * * * * /home/madlab/venv/bin/python3 /home/madlab/dendro-pi-main/dendro_logger/dendro_logging.py 

# Upload dendrometer data to Dropbox every day at 2am
0 2 * * * /home/madlab/venv/bin/python3 /home/madlab/dendro-pi-main/dendro_logger/upload-to-dropbox_DENDRO.sh
````



