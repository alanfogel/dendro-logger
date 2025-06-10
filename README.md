# 🌲 Dendrometer Pi Logging System
This project sets up a Raspberry Pi to read data off of dendrometers, save it to a .csv file, and upload it to Dropbox.

The default behaviour of this system is to read the data off of 4 dendrometers every ___ minutes, and upload the .csv each night to a Dropbox folder named after the Pi's hostname (e.g., `Dorval-8`).

## Prerequisites
- Make sure you have followed the initial setup instructions from: https://github.com/alanfogel/dendro-pi-main


## ⚙️ Initial Setup:
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


