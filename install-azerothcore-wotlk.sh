#!/bin/bash

# credit: https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version
function install(){
	# install dependencies
	echo "###################################"
	echo "Install Azerothcore dependencies..."
	echo "###################################"
	sudo apt-get update && sudo apt-get install -y git cmake make gcc g++ clang libmysqlclient-dev \
		libssl-dev libbz2-dev libreadline-dev libncurses-dev mysql-server libboost-all-dev unzip screen

	# secure MySQL
	echo -e "\n"
	echo "######################"
	echo "Secure MySQL server..."
	echo "######################"
	sudo mysql_secure_installation --use-default

	# set default env variable
	AC_CODE_DIR="/opt/azerothcore-wotlk"
	DB_PASS="P@ssw0rd123"
	INSTALL_USER=$(whoami)
	realmlist_ip=$(hostname -I | awk '{print $1}')
	realmlist_name="AzerothCore"

	# clone Azerothcore github directory
	echo -e "\n"
	echo "##################################"
	echo "Cloning Azerothcore github repo..."
	echo "##################################"
	sudo mkdir -p ${AC_CODE_DIR}
	sudo chown -R ${INSTALL_USER}:${INSTALL_USER} ${AC_CODE_DIR}
	git clone https://github.com/azerothcore/azerothcore-wotlk.git --branch master --single-branch ${AC_CODE_DIR}
	# create extra folders
	mkdir -p ${AC_CODE_DIR}/{data,logs,temp}

	# download client data
	echo -e "\n"
	echo "##############################"
	echo "Download latest client data..."
	echo "##############################"
	LATEST_CLIENT=$(curl -s https://api.github.com/repos/wowgaming/client-data/releases/latest 2>/dev/null | \
		grep '"tag_name"' | cut -d'"' -f4 || echo "unknown")
	wget -q --show-progress https://github.com/wowgaming/client-data/releases/download/${LATEST_CLIENT}/Data.zip -P /tmp
	unzip /tmp/Data.zip -d ${AC_CODE_DIR}/data
	echo "${LATEST_CLIENT}" > ${AC_CODE_DIR}/data/.version
	echo "Done extract client data to ${AC_CODE_DIR}/data."

	# start compiling azerothcore
	echo -e "\n"
	echo "########################"
	echo "Compiling Azerothcore..."
	echo "########################"
	mkdir -p ${AC_CODE_DIR}/build && cd ${AC_CODE_DIR}/build

	cmake ../ -DCMAKE_INSTALL_PREFIX=${AC_CODE_DIR}/env/dist/ \
		-DCMAKE_C_COMPILER=/usr/bin/clang \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
		-DWITH_WARNINGS=1 \
		-DTOOLS_BUILD=all \
		-DSCRIPTS=static \
		-DMODULES=static
	#export BUILD_CORES=`nproc | awk '{print $1 - 1}'`
	make -j$(nproc)
	make install

	# copy and create Azerothcore config files
	echo -e "\n"
	echo "#####################################"
	echo "Configure Azerothcore config files..."
	echo "#####################################"
	cp ${AC_CODE_DIR}/env/dist/etc/authserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/authserver.conf
	cp ${AC_CODE_DIR}/env/dist/etc/worldserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/worldserver.conf

	# configure worldserver.conf
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_auth\"|" \
		${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	sed -i "s|^WorldDatabaseInfo.*|WorldDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_world\"|" \
		${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	sed -i "s|^CharacterDatabaseInfo.*|CharacterDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_characters\"|" \
		${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	sed -i "s|^DataDir.*|DataDir = \"${AC_CODE_DIR}/data\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	sed -i "s|^LogsDir.*|LogsDir = \"${AC_CODE_DIR}/logs\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	sed -i "s|^TempDir.*|TempDir = \"${AC_CODE_DIR}/temp\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	echo "Done configure ${AC_CODE_DIR}/env/dist/etc/worldserver.conf."

	# configure authserver.conf
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;acore;${DB_PASS};acore_auth\"|" \
		${AC_CODE_DIR}/env/dist/etc/authserver.conf
	sed -i "s|^LogsDir.*|LogsDir = \"${AC_CODE_DIR}/logs\"|" ${AC_CODE_DIR}/env/dist/etc/authserver.conf
	sed -i "s|^TempDir.*|TempDir = \"${AC_CODE_DIR}/temp\"|" ${AC_CODE_DIR}/env/dist/etc/authserver.conf
	echo "Done configure ${AC_CODE_DIR}/env/dist/etc/authserver.conf."

	# Azerothcore database setup
	echo -e "\n"
	echo "#############################"
	echo "Setup Azerothcore database..."
	echo "#############################"
	sudo mysql -e "DROP USER IF EXISTS 'acore'@'localhost';"
	sudo mysql -e "CREATE USER IF NOT EXISTS 'acore'@'localhost' IDENTIFIED BY '${DB_PASS}';"
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_world;"
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_characters;"
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_auth;"
	sudo mysql -e "GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'localhost';"
	sudo mysql -e "GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'localhost';"
	sudo mysql -e "GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'localhost';"
	sudo mysql -e "FLUSH PRIVILEGES;"
	echo "Done configure Azerothcore database."

	# Create systemd file for Azerothcore service
	echo -e "\n"
	echo "###########################################"
	echo "Create Azerothcore systemd service files..."
	echo "###########################################"
	cat <<-EOF | sudo tee /etc/systemd/system/ac-authserver.service > /dev/null
		[Unit]
		Description=AzerothCore Authserver
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=${AC_CODE_DIR}
		ExecStart=${AC_CODE_DIR}/acore.sh run-authserver

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF | sudo tee /etc/systemd/system/ac-worldserver.service > /dev/null
		[Unit]
		Description=AzerothCore Worldserver
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=${AC_CODE_DIR}
		ExecStart=/bin/screen -S worldserver -D -m ${AC_CODE_DIR}/acore.sh run-worldserver

		[Install]
		WantedBy=multi-user.target
	EOF
	echo "Done create systemd service files."

	echo "########################################"
	echo "Enable and start Azerothcore services..."
	echo "########################################"
	sudo systemctl daemon-reload
	sudo systemctl enable --now ac-authserver.service
	sudo systemctl enable --now ac-worldserver.service

	# Wait 1 minute for Azerothcore to initialize the database and service
	secs=60; while [ $secs -gt 0 ]; do echo -ne "Staring Azerothcore services in $secs seconds...\r"; sleep 1; : $((secs--)); done; echo -e "\nDone!"

	# set Azerothcore realmlist IP and Name
	echo -e "\n"
	echo "##########################################"
	echo "Set Azerothcore realmlist and realmname..."
	echo "##########################################"
	sudo mysql -e "UPDATE acore_auth.realmlist SET address = '${realmlist_ip}' WHERE id = 1;"
	sudo mysql -e "UPDATE acore_auth.realmlist SET name = '${realmlist_name}' WHERE id = 1;"
	echo "Done configure Realmlist IP and Hostname."

	# remove build directory
	echo -e "\n"
	echo "###################"
	echo "Cleanup old data..."
	echo "###################"
	sudo rm -r ${AC_CODE_DIR}/build
	sudo rm /tmp/Data.zip
	echo "Done removing old data."
}

# installation menu selection
if [[ -r /etc/os-release ]]; then
	. /etc/os-release
	ID=$ID
	CODENAME=$VERSION_CODENAME
	#CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
	#echo $CODENAME
	if [[ $CODENAME == "noble" ]]; then
		install
	else
		echo "Not running Ubuntu 24.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
