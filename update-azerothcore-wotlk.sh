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

function check_update(){
    # set default variable
	AC_CODE_DIR="/opt/azerothcore-wotlk"
    DB_USER="acore"
	DB_PASS="P@ssw0rd123"
	AC_UPDATE="YES"

	if [[ -d ${AC_CODE_DIR} ]]; then
        # Check update status for Azerothcore files
		echo "##########################################"
		echo "#...Checking Azerothcore update status...#"
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
		echo "#...Azerothcore Update Summary...#"
		echo "##################################"
		echo -e "Azerothcore Update Available : ${AC_UPDATE}"
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
	echo "#...Disable Azerothcore services...#"
	echo "####################################"
	sudo systemctl stop ac-authserver
	sudo systemctl stop ac-worldserver
	echo "Azerothcore services stopped!"

	echo -e
	echo "##########################################"
	echo "#...Updating Azerothcore git directory...#"
	echo "##########################################"
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
	echo "#...Re-compiling Azerothcore...#"
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
	echo "Done compling latest Azerothcore source code."

	# copy and create Azerothcore config files
	echo -e
	echo "##########################################"
	echo "#...Configure Azerothcore config files...#"
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

	echo -e
	echo "###############################"
	echo "Start Azerothcore services..."
	echo "###############################"
	sudo systemctl start ac-authserver
	sudo systemctl start ac-worldserver
	echo "Done started Azerothcore service."
}

# installation menu selection
if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        ID=$ID
        CODENAME=$VERSION_CODENAME
        #CODENAME=$(cat /etc/os-release | grep _CODENAME | cut -d = -f 2)
        #echo $CODENAME
        if [[ $CODENAME == "noble" ]]; then
                update
        else
                echo "Not running Ubuntu 24.04 LTS distribution. Exiting..."
                exit;
        fi
else
        echo "Not running a distribution with /etc/os-release available"
        exit;
fi
