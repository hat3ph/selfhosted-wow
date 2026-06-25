#!/bin/bash

# https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version
function install(){
	# install dependencies
	sudo apt-get update && sudo apt-get install -y git cmake make gcc g++ clang libmysqlclient-dev libssl-dev libbz2-dev libreadline-dev libncurses-dev mysql-server libboost-all-dev unzip screen
	
	# setup secure MySQL
	#sudo mysql_secure_installation
	
	# set default env variable
	AC_CODE_DIR="/opt/azerothcore-wotlk"
	DB_PASS="P@ssw0rd123"
	INSTALL_USER=$(whoami)
	
	# create Azerothcore directory
	sudo mkdir -p $AC_CODE_DIR/{data,logs,temp}
	
	# clone Azerothcore github directory
	sudo git clone https://github.com/azerothcore/azerothcore-wotlk.git --branch master --single-branch $AC_CODE_DIR
	
	# start compiling azerothcore
	cd $AC_CODE_DIR
	sudo mkdir build && cd build
	
	sudo cmake ../ -DCMAKE_INSTALL_PREFIX=$AC_CODE_DIR \
		-DCMAKE_C_COMPILER=/usr/bin/clang \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
		-DWITH_WARNINGS=1 \
		-DTOOLS_BUILD=all \
		-DSCRIPTS=static \
		-DMODULES=static
	#export BUILD_CORES=`nproc | awk '{print $1 - 1}'`
	sudo make -j$(nproc)
	sudo make install
	
	# copy and create Azerothcore config files
	sudo cp $AC_CODE_DIR/etc/authserver.conf.dist $AC_CODE_DIR/etc/authserver.conf
	sudo cp $AC_CODE_DIR/etc/worldserver.conf.dist $AC_CODE_DIR/etc/worldserver.conf
	
	# configure worldserver.conf
	sudo sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_auth\"|" $AC_CODE_DIR/etc/worldserver.conf
	sudo sed -i "s|^WorldDatabaseInfo.*|WorldDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_world\"|" $AC_CODE_DIR/etc/worldserver.conf
	sudo sed -i "s|^CharacterDatabaseInfo.*|CharacterDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_characters\"|" $AC_CODE_DIR/etc/worldserver.conf
	sudo sed -i "s|^DataDir.*|DataDir = \"$AC_CODE_DIR/data\"|" $AC_CODE_DIR/etc/worldserver.conf
	sudo sed -i "s|^LogsDir.*|LogsDir = \"$AC_CODE_DIR/logs\"|" $AC_CODE_DIR/etc/worldserver.conf
	sudo sed -i "s|^TempDir.*|TempDir = \"$AC_CODE_DIR/temp\"|" $AC_CODE_DIR/etc/worldserver.conf
	
	# configure authserver.conf
	sudo sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_auth\"|" $AC_CODE_DIR/etc/authserver.conf
	sudo sed -i "s|^LogsDir.*|LogsDir = \"$AC_CODE_DIR/logs\"|" $AC_CODE_DIR/etc/authserver.conf
	sudo sed -i "s|^TempDir.*|TempDir = \"$AC_CODE_DIR/temp\"|" $AC_CODE_DIR/etc/authserver.conf
	
	# download client data
	wget https://github.com/wowgaming/client-data/releases/download/v19/Data.zip -P /tmp
	sudo unzip /tmp/Data.zip -d $AC_CODE_DIR/data
	
	# Azerothcore database setup
	#sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_world;"
	#sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_characters;"
	#sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_auth;"
	#sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_playerbots;"
	#sudo mysql -e "CREATE USER IF NOT EXISTS 'acore'@'localhost' IDENTIFIED BY '${DB_PASS}';"
	#sudo mysql -e "GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'localhost';"
	#sudo mysql -e "GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'localhost';"
	#sudo mysql -e "GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'localhost';"
	#sudo mysql -e "GRANT ALL PRIVILEGES ON acore_playerbots.* TO 'acore'@'localhost';"
	#sudo mysql -e "FLUSH PRIVILEGES;"
	
	# set Azerothcore realmlist IP
	#ip_address=$(hostname -I | awk '{print $1}')
	#echo $ip_address
	#sudo mysql -e "UPDATE acore_auth.realmlist SET address = '${ip_address}' WHERE id = 1;"
	
	# Create systemd file for Azerothcore service
	cat <<-EOF | tee $AC_CODE_DIR/ac-authserver.service > /dev/null
		[Unit]
		Description=AzerothCore Authserver
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=$AC_CODE_DIR
		ExecStart=$AC_CODE_DIR/acore.sh run-authserver

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF | tee $AC_CODE_DIR/ac-worldserver.service > /dev/null
		[Unit]
		Description=AzerothCore Worldserver
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=$AC_CODE_DIR
		ExecStart=/bin/screen -S worldserver -D -m $AC_CODE_DIR/acore.sh run-worldserver

		[Install]
		WantedBy=multi-user.target
	EOF
	
	#sudo systemctl daemon-reload
	#sudo systemctl enable --now ac-authserver.service
	#sudo systemctl enable --now ac-worldserver.service
}

# installation menu selection
if [[ -r /etc/os-release ]]; then
	. /etc/os-release
	ID=$ID
	CODENAME=$VERSION_CODENAME
	#CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
	#echo $CODENAME
	if [[ $CODENAME == "resolute" ]]; then
		install
	else
		echo "Not running Ubuntu 24.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
