#!/bin/bash

# credit to below links
# https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version
# https://archive.org/download/wow_clients
# https://github.com/cmangos/issues/wiki/Installation-Instructions
# https://github.com/celguar/spp-classics-cmangos/releases

function check_update(){
	# set default env variable
	CMGS_CODE_DIR="/opt/cmangos"
	DB_USER="mangos"
	DB_PASS="P@ssw0rd123"
	CMGS_UPDATE="YES"
	DB_UPDATE="YES"
	INSTALL_USER=$(whoami)
	PLAYERBOTS="OFF" #Turn player bot on or off
	AHBOT="OFF" #Turn auction house bot on or off

	if [[ ${1} == "classic" ]]; then
		REALMD_DB="classicrealmd"
		MANGOSD_DB="classicmangos"
		CHARS_DB="classiccharacters"
		LOGS_DB="classiclogs"
	fi
	if [[ ${1} == "tbc" ]]; then
		REALMD_DB="tbcrealmd"
		MANGOSD_DB="tbcmangos"
		CHARS_DB="tbccharacters"
		LOGS_DB="tbclogs"
	fi
	if [[ ${1} == "wotlk" ]]; then
		REALMD_DB="wotlkrealmd"
		MANGOSD_DB="wotlkmangos"
		CHARS_DB="wotlkcharacters"
		LOGS_DB="wotlklogs"
	fi

	if [[ -d ${CMGS_CODE_DIR}/mangos-${1} ]]; then
		# Check update status for CMaNGOS files
		echo "######################################"
		echo "#...Checking CMaNGOS update status...#"
		echo "######################################"
		cd ${CMGS_CODE_DIR}/mangos-${1}
		git fetch origin
		if [[ $(git rev-list HEAD...origin/master --count) == 0 ]]; then
			echo "Folder ${CMGS_CODE_DIR}/mangos-${1} already updated."
			CMGS_UPDATES="NO"
		else
			echo "Updates available for ${CMGS_CODE_DIR}/mangos-${1}. Run update-cmangos.sh script to update the codes."
		fi

		cd ${CMGS_CODE_DIR}/mangos-${1}/${1}-db
		git fetch origin
		if [[ $(git rev-list HEAD...origin/master --count) == 0 ]]; then
			echo "Folder ${CMGS_CODE_DIR}/mangos-${1} already updated."
			DB_UPDATES="NO"
		else
			echo "Updates available for ${CMGS_CODE_DIR}/mangos-${1}. Run update-cmangos.sh script to update the codes."
		fi

		# summary of the updates
		echo -e
		echo "##############################"
		echo "#...CMaNGOS Update Summary...#"
		echo "##############################"
		echo -e "CMGS Update Available : ${CMGS_UPDATES}"
		echo -e "DB Update Available : ${DB_UPDATES}"
		while true; do
		read -p "Do you want to proceed with above summary? (y/n) " yn
			case $yn in
				[yY] ) echo ok, we will proceed; update ${1};
					break;;
				[nN] ) echo exiting...;
					exit;;
				* ) echo invalid response;;
			esac
		done
	else
		echo "Folder ${CMGS_CODE_DIR}/mangos-${1} not available. Aborting checking operation!"
		exit;
	fi
}

function update(){
	# enable playerbot and ahbot if config files available
	if [[ -f ${CMGS_CODE_DIR}/run/etc/aiplayerbot.conf ]]; then
		PLAYERBOTS="ON"
	fi
	if [[ -f ${CMGS_CODE_DIR}/run/etc/ahbot.conf ]]; then
		AHBOT="ON"
	fi

	echo "################################"
	echo "#...Stopping CMaNGOS serices...#"
	echo "################################"
	sudo systemctl stop mangosd.service
	sudo systemctl stop realmd.service

	echo -e
	echo "###########################"
	echo "#...Backup CMaNGOS Data...#"
	echo "###########################"
	mkdir -p ${CMGS_CODE_DIR}/backup
	cat <<-EOF | tee ${CMGS_CODE_DIR}/backup/.db_cred.cnf > /dev/null
		[mysqldump]
		user=${DB_USER}
		password=${DB_PASS}
	EOF
	chmod 600 ${CMGS_CODE_DIR}/backup/.db_cred.cnf
	mysqldump --defaults-extra-file=${CMGS_CODE_DIR}/backup/.db_cred.cnf ${REALMD_DB} > ${CMGS_CODE_DIR}/backup/mangos-${1}-${REALMD_DB}-$(date +%Y_%m_%d_%H_%M_%S).sql
	mysqldump --defaults-extra-file=${CMGS_CODE_DIR}/backup/.db_cred.cnf ${MANGOSD_DB} > ${CMGS_CODE_DIR}/backup/mangos-${1}-${MANGOSD_DB}-$(date +%Y_%m_%d_%H_%M_%S).sql
	mysqldump --defaults-extra-file=${CMGS_CODE_DIR}/backup/.db_cred.cnf ${CHARS_DB} > ${CMGS_CODE_DIR}/backup/mangos-${1}-${CHARS_DB}-$(date +%Y_%m_%d_%H_%M_%S).sql
	mysqldump --defaults-extra-file=${CMGS_CODE_DIR}/backup/.db_cred.cnf ${LOGS_DB} > ${CMGS_CODE_DIR}/backup/mangos-${1}-${LOGS_DB}-$(date +%Y_%m_%d_%H_%M_%S).sql
	tar -czvf mangos-${1}-sqlbak-$(date +%Y_%m_%d_%H_%M_%S).tar.gz *.sql
	rm ${CMGS_CODE_DIR}/backup/*.sql
	rm ${CMGS_CODE_DIR}/backup/.db_cred.cnf
	echo "Done backup SQL DB to ${CMGS_CODE_DIR}/backup."
	
	# backup current CMaNGOS folder
	cp -r ${CMGS_CODE_DIR} $HOME/cmangos-$(date +%Y_%m_%d_%H)
	echo "Done backup CMaNGOS data to $HOME/cmangos-$(date +%Y_%m_%d_%H)"

	# updating CMaNGOS github directory
	echo -e
	echo "#############################"
	echo "#...Updating CMaNGOS data...#"
	echo "#############################"
	cd ${CMGS_CODE_DIR}/mangos-${1}
	git fetch origin
	echo "Updating ${CMGS_CODE_DIR}/mangos-${1}."
	git pull origin master

	# updating db files
	cd ${CMGS_CODE_DIR}/mangos-${1}/${1}-db
	git fetch origin
	echo "Updating ${CMGS_CODE_DIR}/mangos-${1}/${1}-db."
	git pull origin master

	# start re-compiling CMaNGOS if there is update 
	echo -e
	echo "########################################"
	echo "#...Re-compiling CMaNGOS source code...#"
	echo "########################################"
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
	echo -e
	echo "######################################"
	echo "#...Configure CMaNGOS config files...#"
	echo "######################################"
	cp ${CMGS_CODE_DIR}/run/etc/mangosd.conf.dist ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	cp ${CMGS_CODE_DIR}/run/etc/realmd.conf.dist ${CMGS_CODE_DIR}/run/etc/realmd.conf
	cp ${CMGS_CODE_DIR}/run/etc/anticheat.conf.dist ${CMGS_CODE_DIR}/run/etc/anticheat.conf
	if [[ ${PLAYERBOTS} == "ON" ]]; then
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
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${REALMD_DB}\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^WorldDatabaseInfo.*|WorldDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${MANGOSD_DB}\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^CharacterDatabaseInfo.*|CharacterDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${CHARS_DB}\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	sed -i "s|^LogsDatabaseInfo.*|LogsDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${LOGS_DB}\"|" ${CMGS_CODE_DIR}/run/etc/mangosd.conf
	echo "Done configure ${CMGS_CODE_DIR}/run/etc/mangosd.conf."

	# configure realmd.conf
	sed -i "s|^LogsDir.*|LogsDir = \"${CMGS_CODE_DIR}/logs\"|" ${CMGS_CODE_DIR}/run/etc/realmd.conf
	sed -i "s|^LoginDatabaseInfo.*|LoginDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};${REALMD_DB}\"|" ${CMGS_CODE_DIR}/run/etc/realmd.conf
	echo "Done configure ${CMGS_CODE_DIR}/run/etc/realmd.conf."

	# Updating CMaNGOS database
	echo -e
	echo "#################################"
	echo "#...Updating CMaNGOS database...#"
	echo "#################################"
	cd ${CMGS_CODE_DIR}/mangos-${1}/${1}-db
	# generate database config if missing
	if [[ ! -f ${CMGS_CODE_DIR}/mangos-${1}/${1}-db/InstallFullDB.config ]]; then
		echo "Database config file is missing, rebuilding it now!!!"
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
	fi
	bash InstallFullDB.sh -UpdateCore
	echo "Done updating CMaNGOS database."

	echo -e
	echo "###################################"
	echo "#...Restarting CMaNGOS services...#"
	echo "###################################"
	sudo systemctl start realmd.service
	sudo systemctl start mangosd.service

	# Wait 1 minute for CMaNGOS to initialize the database and service
	secs=60; while [ $secs -gt 0 ]; do echo -ne "Staring CMaNGOS services in $secs seconds...\r"; sleep 1; : $((secs--)); done; echo -e "\nDone!"

	# remove build directory
	echo -e
	echo "########################"
	echo "#...Cleanup old data...#"
	echo "########################"
	sudo rm -r ${CMGS_CODE_DIR}/build
	echo "Done removing build data."
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
			check_update ${1}
		fi
	else
		echo "Not running Ubuntu 24.04/26.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
