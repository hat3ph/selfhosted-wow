#!/bin/bash

# credit: https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version

cat << "EOF"
     _                       _   _      ____
    / \    _______ _ __ ___ | |_| |__  / ___|___  _ __ ___
   / _ \  |_  / _ \ '__/ _ \| __| '_ \| |   / _ \| '__/ _ \
  / ___ \  / /  __/ | | (_) | |_| | | | |__| (_) | | |  __/
 /_/__ \_\/___\___|_|  \___/ \__|_| |_|\____\___/|_|  \___|
 |  _ \| | __ _ _   _  ___ _ __| |__   ___ | |_
 | |_) | |/ _` | | | |/ _ \ '__| '_ \ / _ \| __|
 |  __/| | (_| | |_| |  __/ |  | |_) | (_) | |
 |_|   |_|\__,_|\__, |\___|_|  |_.__/ \___/ \__|
                |___/https://www.azerothcore.org
EOF

function check_update(){
    # set default variable
	AC_CODE_DIR="/opt/azerothcore-wotlk-playerbot"
	DB_USER="acore"
	DB_PASS="P@ssw0rd123"
	AC_UPDATE="YES"

	if [[ -d ${AC_CODE_DIR} ]]; then
        # Check update status for AzerothCore files
		echo -e
		echo "##########################################"
		echo "#...Checking AzerothCore update status...#"
		echo "##########################################"
		cd ${AC_CODE_DIR}
		git fetch origin
		if [[ $(git rev-list HEAD...origin/master --count) == 0 ]]; then
			echo "Folder ${AC_CODE_DIR} already updated."
			AC_UPDATE="NO"
		else
			echo "Updates available for ${AC_CODE_DIR}."
		fi

		# summary of the updates
		echo -e
		echo "##################################"
		echo "#...AzerothCore Update Summary...#"
		echo "##################################"
		echo -e "AzerothCore Update Available : ${AC_UPDATE}"
		while true; do
		read -p "Do you want to proceed with above summary? (y/n) " yn
			case $yn in
				[yY] ) echo ok, we will proceed; update;
					break;;
				[nN] ) echo exiting...;
					exit;;
				* ) echo invalid response;;
			esac
		done
	else
		echo "Folder ${AC_CODE_DIR} not available. Aborting checking operation!"
		exit;
	fi
}

function update(){
	echo -e
	echo "####################################"
	echo "#...Disable AzerothCore services...#"
	echo "####################################"
	sudo systemctl stop acbot-authserver
	sudo systemctl stop acbot-worldserver
	echo "AzerothCore services stopped!"

	echo -e
	echo "###############################"
	echo "#...Backup AzerothCore Data...#"
	echo "###############################"
	mkdir -p ${AC_CODE_DIR}/backup
	sudo mysqldump acore_world > ${AC_CODE_DIR}/backup/acore_world-$(date +%Y_%m_%d_%H_%M_%S).sql
	sudo mysqldump acore_characters > ${AC_CODE_DIR}/backup/acore_characters-$(date +%Y_%m_%d_%H_%M_%S).sql
	sudo mysqldump acore_auth > ${AC_CODE_DIR}/backup/acore_auth-$(date +%Y_%m_%d_%H_%M_%S).sql
	sudo mysqldump acore_playerbots > ${AC_CODE_DIR}/backup/acore_playerbots-$(date +%Y_%m_%d_%H_%M_%S).sql
	cd ${AC_CODE_DIR}/backup
	tar -czvf azerothcore-playerbot-sqlbak-$(date +%Y_%m_%d_%H_%M_%S).tar.gz *.sql
	rm ${AC_CODE_DIR}/backup/*.sql
	echo "Done backup SQL DB to ${AC_CODE_DIR}/backup."

	# backup current Azerothcore folder
	cp -r ${AC_CODE_DIR} $HOME/azerothcore-wotlk-playerbot-$(date +%Y_%m_%d_%H)
	echo "Done backup AzerothCore data to $HOME/azerothcore-wotlk-playerbot-$(date +%Y_%m_%d_%H)"

	echo -e
	echo "##########################################"
	echo "#...Updating AzerothCore git directory...#"
	echo "##########################################"
	# updating AzerothCore modules
	for i in $(ls ${AC_CODE_DIR}/modules | grep "mod-"); do
		cd ${AC_CODE_DIR}/modules/${i}
		echo "Updating ${AC_CODE_DIR}/modules/${i}"
		git pull origin master
	done
	# updating AzerothCore source code
	cd ${AC_CODE_DIR}
	git pull origin master

	echo -e
	echo "######################################"
	echo "#...Checking latesting client data...#"
	echo "######################################"
	LATEST_CLIENT=$(curl -s https://api.github.com/repos/wowgaming/client-data/releases/latest 2>/dev/null | \
		grep '"tag_name"' | cut -d'"' -f4 || echo "unknown")
	CURRENT_CLIENT=$(cat ${AC_CODE_DIR}/data/.version 2>/dev/null || echo "unknown")
	if [ "${CURRENT_CLIENT}" = "${LATEST_CLIENT}" ] && [ "${CURRENT_CLIENT}" != "unknown" ]; then
		echo "Client data is up to date"
	else
		wget -q --show-progress https://github.com/wowgaming/client-data/releases/download/${LATEST_CLIENT}/Data.zip -P /tmp
		unzip /tmp/Data.zip -d ${AC_CODE_DIR}/data
		echo "${LATEST_CLIENT}" > ${AC_CODE_DIR}/data/.version
		echo "Done update client data to version ${LATEST_CLIENT}."
	fi

	echo -e
	echo "################################"
	echo "#...Re-compiling AzerothCore...#"
	echo "################################"
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
	echo "Done compling latest AzerothCore source code."

	# copy and create Azerothcore config files
	echo -e
	echo "##########################################"
	echo "#...Configure AzerothCore config files...#"
	echo "##########################################"
	cp ${AC_CODE_DIR}/env/dist/etc/authserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/authserver.conf
	cp ${AC_CODE_DIR}/env/dist/etc/worldserver.conf.dist ${AC_CODE_DIR}/env/dist/etc/worldserver.conf
	cp ${AC_CODE_DIR}/env/dist/etc/modules/playerbots.conf.dist ${AC_CODE_DIR}/env/dist/etc/modules/playerbots.conf
	cp ${AC_CODE_DIR}/env/dist/etc/modules/mod_ahbot.conf.dist ${AC_CODE_DIR}/env/dist/etc/modules/mod_ahbot.conf

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

	# configure playerbots.conf
	sed -i "s|^PlayerbotsDatabaseInfo.*|PlayerbotsDatabaseInfo = \"127.0.0.1;3306;${DB_USER};${DB_PASS};acore_playerbots\"|" \
		${AC_CODE_DIR}/env/dist/etc/modules/playerbots.conf
	# reduce bots count for low resource system
	sed -i "s|^AiPlayerbot.MinRandomBots =.*|AiPlayerbot.MinRandomBots = 50|" ${AC_CODE_DIR}/env/dist/etc/modules/playerbots.conf
	sed -i "s|^AiPlayerbot.MaxRandomBots =.*|AiPlayerbot.MaxRandomBots = 50|" ${AC_CODE_DIR}/env/dist/etc/modules/playerbots.conf

	# configure mod_ahbot.conf
	sed -i "s|^AuctionHouseBot.GUIDs.*|AuctionHouseBot.GUIDs = 1|" ${AC_CODE_DIR}/env/dist/etc/modules/mod_ahbot.conf
	sed -i "s|^AuctionHouseBot.EnableSeller.*|AuctionHouseBot.EnableSeller = true|" ${AC_CODE_DIR}/env/dist/etc/modules/mod_ahbot.conf

	echo -e
	echo "###############################"
	echo "Start AzerothCore services..."
	echo "###############################"
	sudo systemctl start acbot-authserver
	sudo systemctl start acbot-worldserver
	echo "Done started AzerothCore service."
}

# check runing OS
if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        ID=$ID
        CODENAME=$VERSION_CODENAME
        #CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
        #echo $CODENAME
        if [[ $CODENAME == "noble" ]]; then
                check_update
        else
                echo "Not running Ubuntu 24.04 LTS distribution. Exiting..."
                exit;
        fi
else
        echo "Not running a distribution with /etc/os-release available"
        exit;
fi
