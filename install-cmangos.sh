#!/bin/bash

# credit to below links
# https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version
# https://archive.org/download/wow_clients
# https://github.com/cmangos/issues/wiki/Installation-Instructions
# https://github.com/celguar/spp-classics-cmangos/releases

function install(){
	# install dependencies
	echo "###################################"
	echo "Install CMaNGOS dependencies..."
	echo "###################################"

	sudo apt-get install -y git build-essential gcc g++ automake git-core autoconf make patch \
		libmysql++-dev mysql-server libtool libssl-dev grep binutils zlib1g-dev libbz2-dev cmake \
		libboost-all-dev libicu-dev screen unzip 7zip

	# secure MySQL
	echo -e "\n"
	echo "######################"
	echo "Secure MySQL server..."
	echo "######################"
	sudo mysql_secure_installation --use-default

	# set default env variable
	CMGS_CODE_DIR="/opt/cmangos"
	DB_USER="mangos"
	DB_PASS="P@ssw0rd123"
	INSTALL_USER=$(whoami)
	PLAYERBOTS="OFF" #Turn player bot on or off
	AHBOT="OFF" #Turn auction house bot on or off
	REALMLIST_IP=$(hostname -I | awk '{print $1}')
	if [[ ${1} == "classic" ]]; then
		REALMD_DB="classicrealmd"
		MANGOSD_DB="classicmangos"
		CHARS_DB="classiccharacters"
		LOGS_DB="classiclogs"
		REALMLIST_NAME="CMaNGOS Classic"
	fi
	if [[ ${1} == "tbc" ]]; then
		REALMD_DB="tbcrealmd"
		MANGOSD_DB="tbcmangos"
		CHARS_DB="tbccharacters"
		LOGS_DB="tbclogs"
		REALMLIST_NAME="CMaNGOS TBC"
	fi
	if [[ ${1} == "wotlk" ]]; then
		REALMD_DB="wotlkrealmd"
		MANGOSD_DB="wotlkmangos"
		CHARS_DB="wotlkcharacters"
		LOGS_DB="wotlklogs"
		REALMLIST_NAME="CMaNGOS WotLK"
	fi

	# clone CMaNGOS github directory
	echo -e "\n"
	echo "###############################"
	echo "Cloning CMaNGOS github repo..."
	echo "###############################"
	sudo mkdir -p ${CMGS_CODE_DIR}
	sudo chown -R ${INSTALL_USER}:${INSTALL_USER} ${CMGS_CODE_DIR}
	git clone https://github.com/cmangos/mangos-${1}.git ${CMGS_CODE_DIR}/mangos-${1}
	mkdir -p ${CMGS_CODE_DIR}/{run,data,logs}

	# download db files
	echo -e "\n"
	echo "##########################"
	echo "Download database files..."
	echo "##########################"
	cd ${CMGS_CODE_DIR}/mangos-${1}
	git clone https://github.com/cmangos/${1}-db.git

	# download classic client data
	echo -e "\n"
	echo "#######################"
	echo "Download client data..."
	echo "#######################"
	if [[ ${1} == "classic" ]]; then
		echo "Downloading https://github.com/celguar/spp-classics-cmangos/releases/download/v2.0/vanilla.7z"
		wget -q --show-progress https://github.com/celguar/spp-classics-cmangos/releases/download/v2.0/vanilla.7z -O /tmp/data.7z
	else
		echo "Downloading https://github.com/celguar/spp-classics-cmangos/releases/download/v2.0/${1}.7z"
		wget -q --show-progress https://github.com/celguar/spp-classics-cmangos/releases/download/v2.0/${1}.7z -O /tmp/data.7z
	fi
	7z x /tmp/data.7z -o${CMGS_CODE_DIR}/data
	echo "Done extract client data to ${CMGS_CODE_DIR}/data."

	# start compiling CMaNGOS
	echo -e "\n"
	echo "####################"
	echo "Compiling CMaNGOS..."
	echo "####################"
	mkdir -p ${CMGS_CODE_DIR}/build && cd ${CMGS_CODE_DIR}/build

	cmake ../mangos-${1} -DCMAKE_INSTALL_PREFIX=${CMGS_CODE_DIR}/run \
		-DBUILD_EXTRACTORS=ON \
		-DPCH=1 \
		-DBUILD_PLAYERBOTS=${PLAYERBOTS} \
		-DBUILD_AHBOT=${AHBOT} \
		-DDEBUG=0
	make -j$(nproc)
	make install

	# copy and create CMaNGOS config files
	echo -e "\n"
	echo "#################################"
	echo "Configure CMaNGOS config files..."
	echo "#################################"
	cp ${CMGS_CODE_DIR}/run/etc/mangosd.conf.dist ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	cp ${CMGS_CODE_DIR}/run/etc/realmd.conf.dist ${CMGS_CODE_DIR}/run/etc/realmd.conf
	cp ${CMGS_CODE_DIR}/run/etc/anticheat.conf.dist ${CMGS_CODE_DIR}/run/etc/anticheat.conf
	if [[ ${PLAYERBOTS} == "ON" ]]; then
		cp ${CMGS_CODE_DIR}/run/etc/aiplayerbot.conf.dist ${CMGS_CODE_DIR}/run/etc/aiplayerbot.conf
		# reduce AI playbot count to reduce server load
		sed -i "s|^AiPlayerbot.MinRandomBots.*|AiPlayerbot.MinRandomBots = \"50\"|" ${CMGS_CODE_DIR}/run/etc/aiplayerbot.conf
		sed -i "s|^AiPlayerbot.MaxRandomBots.*|AiPlayerbot.MaxRandomBots = \"50\"|" ${CMGS_CODE_DIR}/run/etc/aiplayerbot.conf
	fi
	if [[ ${AHBOT} == "ON" ]]; then
		cp ${CMGS_CODE_DIR}/run/etc/ahbot.conf.dist ${CMGS_CODE_DIR}/run/etc/ahbot.conf
	fi

	# configure mangosd.conf
	sed -i "s|^DataDir.*|DataDir = \"${CMGS_CODE_DIR}/data\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^LogsDir.*|LogsDir = \"${CMGS_CODE_DIR}/logs\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${REALMD_DB}\"|" \
		${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^WorldDatabaseInfo.*|WorldDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${MANGOSD_DB}\"|" \
		${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^CharacterDatabaseInfo.*|CharacterDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${CHARS_DB}\"|" \
		${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^LogsDatabaseInfo.*|LogsDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${LOGS_DB}\"|" \
		${CMGS_CODE_DIR}/run/etc/mangosd.conf
	echo "Done configure ${CMGS_CODE_DIR}/run/etc/mangosd.conf."

	# configure realmd.conf
	sed -i "s|^LogsDir.*|LogsDir = \"${CMGS_CODE_DIR}/logs\"|" ${CMGS_CODE_DIR}/run/etc/realmd.conf
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${REALMD_DB}\"|" \
		${CMGS_CODE_DIR}/run/etc/realmd.conf
	echo "Done configure ${CMGS_CODE_DIR}/run/etc/realmd.conf."

	# CMaNGOS database setup
	echo -e "\n"
	echo "#########################"
	echo "Setup CMaNGOS database..."
	echo "#########################"
	sudo mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';"
	sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
	sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;"
	cd ${CMGS_CODE_DIR}/mangos-${1}/${1}-db
	bash InstallFullDB.sh -Config
	sed -i "s|^MYSQL_USERNAME.*|MYSQL_USERNAME=\"${DB_USER}\"|" ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config
	sed -i "s|^MYSQL_PASSWORD.*|MYSQL_PASSWORD=\"${DB_PASS}\"|" ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config
	sed -i "s|^CORE_PATH.*|CORE_PATH=\"${CMGS_CODE_DIR}/mangos-classic\"|" ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config
	if [[ ${PLAYERBOTS} == "ON" ]]; then
		sed -i "s|^PLAYERBOTS_DB.*|PLAYERBOTS_DB=\"${PLAYERBOTS}\"|" ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config
	fi
	if [[ ${AHBOT} == "ON" ]]; then
		sed -i "s|^AHBOT.*|AHBOT=\"${AHBOT}\"|" ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config
	fi
	yes DeleteAll | bash InstallFullDB.sh -InstallAll mangos ${DB_PASS}
	echo "Done configure CMaNGOS database."

	# Create systemd file for CMaNGOS service
	echo -e "\n"
	echo "#######################################"
	echo "Create CMaNGOS systemd service files..."
	echo "#######################################"
	cat <<-EOF | sudo tee /etc/systemd/system/realmd.service > /dev/null
		[Unit]
		Description=CMaNGOS auth service
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=${CMGS_CODE_DIR}/run/bin
		ExecStart=${CMGS_CODE_DIR}/run/bin/realmd -c ${CMGS_CODE_DIR}/run/etc/realmd.conf

		[Install]
		WantedBy=multi-user.target
	EOF

	cat <<-EOF | sudo tee /etc/systemd/system/mangosd.service > /dev/null
		[Unit]
		Description=CMaNGOS world service
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		User=${INSTALL_USER}
		WorkingDirectory=${CMGS_CODE_DIR}/run/bin
		ExecStart=/bin/screen -S mangosd -D -m ${CMGS_CODE_DIR}/run/bin/mangosd -c ${CMGS_CODE_DIR}/run/etc/mangosd.conf

		[Install]
		WantedBy=multi-user.target
	EOF
	echo "Done create systemd service files."

	echo -e "\n"
	echo "####################################"
	echo "Enable and start CMaNGOS services..."
	echo "####################################"
	sudo systemctl daemon-reload
	sudo systemctl enable --now realmd.service
	sudo systemctl enable --now mangosd.service

	# Wait 1 minute for CMaNGOS to initialize the database and service
	secs=60; while [ $secs -gt 0 ]; do echo -ne "Staring CMaNGOS services in $secs seconds...\r"; sleep 1; : $((secs--)); done; echo -e "\nDone!"

	# set CMaNGOS realmlist IP and Name
	echo -e "\n"
	echo "######################################"
	echo "Set CMaNGOS realmlist and realmname..."
	echo "######################################"
	sudo mysql -e "UPDATE ${REALMD_DB}.realmlist SET address = '${REALMLIST_IP}' WHERE id = 1;"
	sudo mysql -e "UPDATE ${REALMD_DB}.realmlist SET name = '${REALMLIST_NAME}' WHERE id = 1;"
	echo "Done configure Realmlist IP and Hostname."

	# remove build directory
	echo -e "\n"
	echo "###################"
	echo "Cleanup old data..."
	echo "###################"
	sudo rm -r ${CMGS_CODE_DIR}/build
	#sudo rm /tmp/data.zip
	echo "Done removing old data."
}

# installation menu selection
if [[ -r /etc/os-release ]]; then
	. /etc/os-release
	ID=$ID
	CODENAME=$VERSION_CODENAME
	#CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
	#echo $CODENAME
	if [[ $CODENAME == "noble" || $CODENAME == "resolute" ]]; then
		if [[ -z $1 || $1 != "classic" && $1 != "tbc" && $1 != "wotlk" ]]; then
			echo "No or wrong arguments provided."
			echo "Usage: $0 {classic|tbc|wotlk}"
		else
			install "$1"
		fi
	else
		echo "Not running Ubuntu 24.04/26.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
