# Self-hosting your own WoW Classic Server using:
Only support Ubuntu 24.04/26.04 LTS and Debian 13 with MySQL database.
## AzerothCore (https://www.azerothcore.org/wiki/home)
Install Warth of the Lick King expansion WoW server.
```
git clone https://github.com/hat3ph/selfhosted-wow
cd selfhosted-wow && chmod +x *.sh
./install-azerothcore-wotlk.sh
```
To install Azerothcore with AI Playerbot and Auction House, run the playerbot installation script.
```
./install-azerothcore-wotlk-playerbot.sh
```
To customize the installation, change/update below env variables in the installation script first.
```
# set default env variable
AC_CODE_DIR="/opt/azerothcore-wotlk"
DB_USER="acore"
DB_PASS="P@ssw0rd123"
INSTALL_USER=$(whoami)
REALMLIST_IP=$(hostname -I | awk '{print $1}')
REALMLIST_NAME="AzerothCore WotLK"
```
To update Azerothcore's run the update script accordingly.
```
# run either script accordingly.
# do make sure the env variable on the update script is correct before proceed.
./update-azerothcore-wotlk.sh
./update-azerothcore-wotlk-playerbot.sh
```
To access the world server, use screen utility to access the session.
```
# https://linuxize.com/post/how-to-use-linux-screen/
# list available terminal session
screen -ls
# access the worldserver session
screen -r worldserver
# detach the screen session
ctrl+a+d
```
## CMaNGOS (https://github.com/cmangos/issues/wiki/Installation-Instructions)
You can choose to install CMaNGOS Classic/TBC/WotLK WoW server.
```
git clone https://github.com/hat3ph/selfhosted-wow
cd selfhosted-wow && chmod +x *.sh
./install-cmangos.sh
  _____     __  __       _   _  _____  ____   _____
 / ____|   |  \/  |     | \ | |/ ____|/ __ \ / ____|
| |        | \  / |     |  \| | |  __  |  | | (___
| |ontinued| |\/| | __ _| . ` | | |_ | |  | |\___ \
| |____    | |  | |/ _` | |\  | |__| | |__| |____) |
 \_____|   |_|  |_| (_| |_| \_|\_____|\____/ \____/
 http://cmangos.net\__,_|     Doing emulation right!

No or wrong arguments provided.
Usage: ./install-cmangos.sh {classic|tbc|wotlk}
```
To customize the installation, change/update below env variables in the installation script first.
```
# set default env variable
CMGS_CODE_DIR="/opt/cmangos"
DB_USER="mangos"
DB_PASS="P@ssw0rd123"
INSTALL_USER=$(whoami)
PLAYERBOTS="OFF" #Turn player bot on or off
AHBOT="OFF" #Turn auction house bot on or off
REALMLIST_IP=$(hostname -I | awk '{print $1}')
```
To enable AI Playerbot and Auction House in CMaNGOS, change variable `PLAYERBOTS` and `AHBOT` to `ON` before installation.

To update CMaNGOS, run `update-cmangos.sh` script. Ensure the env variable on the update script is correct before proceed.

To access the world server, use screen utility to access the session.
```
# https://linuxize.com/post/how-to-use-linux-screen/
# list available terminal session
screen -ls
# access the worldserver session
screen -r mangosd
# detach the screen session
ctrl+a+d
```
## Player account command
Access the world server session and run below command:
```
# create user account
account create playername password
# grant GM access to player
account set gmlevel playername 3 -1
# change player password
account set password playername newpassword newpassword
```
