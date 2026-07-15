#!/bin/bash

# credit: https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version

cat << "EOF"
    _                       _   _      ____
   / \    _______ _ __ ___ | |_| |__  / ___|___  _ __ ___
  / _ \  |_  / _ \ '__/ _ \| __| '_ \| |   / _ \| '__/ _ \
 / ___ \  / /  __/ | | (_) | |_| | | | |__| (_) | | |  __/
/_/   \_\/___\___|_|  \___/ \__|_| |_|\____\___/|_|  \___|
https://www.azerothcore.org
EOF

function install(){
	# install dependencies
	echo -e
	echo "###########################################"
	echo "#...Installing AzerothCore dependencies...#"
	echo "###########################################"
	sudo apt-get update && sudo apt-get install -y git cmake make gcc g++ clang libssl-dev libbz2-dev \
		libreadline-dev libncurses-dev libboost-all-dev unzip screen
	# install mysql server
	if [[ $CODENAME == "trixie" ]]; then
		sudo apt-get install -y gnupg
		MYSQL_APT_CONFIG_VERSION="0.8.36-1"
		wget -P /tmp https://dev.mysql.com/get/mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb
		sudo DEBIAN_FRONTEND="noninteractive" dpkg -i /tmp/mysql-apt-config_${MYSQL_APT_CONFIG_VERSION}_all.deb
		sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y mysql-server libmysqlclient-dev
	else
		sudo apt-get update && sudo apt-get install -y mysql-server libmysqlclient-dev
	fi

	# secure MySQL
	echo -e
	echo "###########################"
	echo "#...Secure MySQL server...#"
	echo "###########################"
	sudo mysql_secure_installation --use-default

	# set default env variable
	AC_CODE_DIR="/opt/azerothcore-wotlk"
	DB_USER="acore"
	DB_PASS="P@ssw0rd123"
	INSTALL_USER=$(whoami)
	REALMLIST_IP=$(hostname -I | awk '{print $1}')
	REALMLIST_NAME="AzerothCore WotLK"

	if [[ -d ${AC_CODE_DIR} ]]; then
		echo -e
		echo "Folder ${AC_CODE_DIR} already exist. Aborting installation!"
		exit;
	else
		# clone AzerothCore github directory
		echo -e
		echo "#######################################"
		echo "#...Cloning AzerothCore github repo...#"
		echo "#######################################"
		sudo mkdir -p ${AC_CODE_DIR}
		sudo chown -R ${INSTALL_USER}:${INSTALL_USER} ${AC_CODE_DIR}
		git clone https://github.com/azerothcore/azerothcore-wotlk.git --branch master --single-branch ${AC_CODE_DIR}
		# create extra folders
		mkdir -p ${AC_CODE_DIR}/{data,logs,temp}

		# download client data
		echo -e
		echo "###################################"
		echo "#...Download latest client data...#"
		echo "###################################"
		LATEST_CLIENT=$(curl -s https://api.github.com/repos/wowgaming/client-data/releases/latest 2>/dev/null | \
			grep '"tag_name"' | cut -d'"' -f4 || echo "unknown")
		wget -q --show-progress https://github.com/wowgaming/client-data/releases/download/${LATEST_CLIENT}/Data.zip -P /tmp
		unzip /tmp/Data.zip -d ${AC_CODE_DIR}/data
		echo "${LATEST_CLIENT}" > ${AC_CODE_DIR}/data/.version
		echo "Done extract client data to ${AC_CODE_DIR}/data."

		if [[ $CODENAME == "resolute" ]]; then
			# fix compile error missing libstdc++ library on Ubuntu 26.04 LTS
			sudo apt-get install -y libstdc++-16-dev
			# fix jemalloc compile error (https://github.com/389ds/389-ds-base/issues/7178)
			sed -i 's|std::__throw_bad_alloc();|throw std::bad_alloc();|' ${AC_CODE_DIR}/deps/jemalloc/src/jemalloc_cpp.cpp
		fi

		# start compiling AzerothCore
		echo -e
		echo "#############################"
		echo "#...Compiling AzerothCore...#"
		echo "#############################"
		mkdir -p ${AC_CODE_DIR}/build && cd ${AC_CODE_DIR}/build

		cmake ../ -DCMAKE_INSTALL_PREFIX=${AC_CODE_DIR}/env/dist/ \
			-DCMAKE_C_COMPILER=/usr/bin/clang \
			-DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
			-DWITH_WARNINGS=1 \
			-DTOOLS_BUILD=all \
			-DSCRIPTS=static \
			-DMODULES=static
		make -j$(nproc)
		make install

		# copy and create AzerothCore config files
		echo -e
		echo "##########################################"
		echo "#...Configure AzerothCore config files...#"
		echo "##########################################"
		cp ${AC_CODE_DIR}/env/dist/etc/authserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/authserver.conf
		cp ${AC_CODE_DIR}/env/dist/etc/worldserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/worldserver.conf

		# configure worldserver.conf
		sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};acore_auth\"|" \
			${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		sed -i "s|^WorldDatabaseInfo.*|WorldDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};acore_world\"|" \
			${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		sed -i "s|^CharacterDatabaseInfo.*|CharacterDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};acore_characters\"|" \
			${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		sed -i "s|^DataDir.*|DataDir = \"${AC_CODE_DIR}/data\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		sed -i "s|^LogsDir.*|LogsDir = \"${AC_CODE_DIR}/logs\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		sed -i "s|^TempDir.*|TempDir = \"${AC_CODE_DIR}/temp\"|" ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
		echo "Done configure ${AC_CODE_DIR}/env/dist/etc/worldserver.conf."

		# configure authserver.conf
		sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};acore_auth\"|" \
			${AC_CODE_DIR}/env/dist/etc/authserver.conf
		sed -i "s|^LogsDir.*|LogsDir = \"${AC_CODE_DIR}/logs\"|" ${AC_CODE_DIR}/env/dist/etc/authserver.conf
		sed -i "s|^TempDir.*|TempDir = \"${AC_CODE_DIR}/temp\"|" ${AC_CODE_DIR}/env/dist/etc/authserver.conf
		echo "Done configure ${AC_CODE_DIR}/env/dist/etc/authserver.conf."

		# Azerothcore database setup
		echo -e
		echo "##################################"
		echo "#...Setup AzerothCore database...#"
		echo "##################################"
		sudo mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';"
		sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
		sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_world;"
		sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_characters;"
		sudo mysql -e "CREATE DATABASE IF NOT EXISTS acore_auth;"
		sudo mysql -e "GRANT ALL PRIVILEGES ON acore_world.* TO '${DB_USER}'@'localhost';"
		sudo mysql -e "GRANT ALL PRIVILEGES ON acore_characters.* TO '${DB_USER}'@'localhost';"
		sudo mysql -e "GRANT ALL PRIVILEGES ON acore_auth.* TO '${DB_USER}'@'localhost';"
		sudo mysql -e "FLUSH PRIVILEGES;"
		echo "Done configure AzerothCore database."

		# Create systemd file for AzerothCore service
		echo -e
		echo "################################################"
		echo "#...Create AzerothCore systemd service files...#"
		echo "################################################"
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
		sudo systemctl daemon-reload
		# Wait 1 minute for AzerothCore to initialize the database and service
		sudo systemctl enable --now ac-authserver.service
		secs=60; while [ $secs -gt 0 ]; do echo -ne "Staring AzerothCore Auth services in $secs seconds...\r"; sleep 1; : $((secs--)); done; echo -e "\nDone!"
		sudo systemctl enable --now ac-worldserver.service
		secs=60; while [ $secs -gt 0 ]; do echo -ne "Staring AzerothCore World services in $secs seconds...\r"; sleep 1; : $((secs--)); done; echo -e "\nDone!"

		# set Azerothcore realmlist IP and Name when service fully first initialled.
		while true; do
    		if [[ $(cat ${AC_CODE_DIR}/logs/Server.log | grep ready) ]]; then
				echo -e
				echo "###############################################"
				echo "#...Set AzerothCore realmlist and realmname...#"
				echo "###############################################"
				sudo mysql -e "UPDATE acore_auth.realmlist SET address = '${REALMLIST_IP}' WHERE id = 1;"
				sudo mysql -e "UPDATE acore_auth.realmlist SET name = '${REALMLIST_NAME}' WHERE id = 1;"
				echo "Done configure ${REALMLIST_IP} and ${REALMLIST_NAME} as Realmlist IP and Hostname ."
				break
			fi
		done

		# remove build directory
		echo -e
		echo "########################"
		echo "#...Cleanup old data...#"
		echo "########################"
		sudo rm -r ${AC_CODE_DIR}/build
		sudo rm /tmp/Data.zip
		echo "Done removing old data."
	fi
}

# check running OS
if [[ -r /etc/os-release ]]; then
	. /etc/os-release
	ID=$ID
	CODENAME=$VERSION_CODENAME
	#CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
	#echo $CODENAME
	if [[ $CODENAME == "noble" || $CODENAME == "resolute" || $CODENAME == "trixie" ]]; then
		install
	else
		echo "Not running Ubuntu 24.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
