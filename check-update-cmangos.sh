#!/bin/bash

# credit to below links
# https://gitea.com/Eldesan/Debian-Trixie-Azerothcore-PlayerBots-llm-Nvidia-And-Slim-version
# https://archive.org/download/wow_clients
# https://github.com/cmangos/issues/wiki/Installation-Instructions
# https://github.com/celguar/spp-classics-cmangos/releases

function check_update(){
	# set default env variable
	CMGS_CODE_DIR="/opt/cmangos"

	if [[ -d ${CMGS_CODE_DIR}/mangos-${1} ]]; then
		# Check update status for CMaNGOS github directorym
		echo "#################################"
		echo "Checking CMaNGOS update status..."
		echo "#################################"
		cd ${CMGS_CODE_DIR}/mangos-${1}
		git fetch origin
		if [[ $(git rev-list HEAD...origin/master --count) == 0 ]]; then
			echo "Folder ${CMGS_CODE_DIR}/mangos-${1} already updated."
		else
			echo "Updates available for ${CMGS_CODE_DIR}/mangos-${1}. Run update-cmangos.sh script to update the codes."
		fi

		# checking update status for CMaNGOS DB files
		echo -e "\n"
		echo "####################################"
		echo "Checking CMaNGOS DB update status..."
		echo "####################################"
		cd ${CMGS_CODE_DIR}/mangos-${1}/${1}-db
		git fetch origin
		if [[ $(git rev-list HEAD...origin/master --count) == 0 ]]; then
			echo "Folder ${CMGS_CODE_DIR}/mangos-${1} already updated."
		else
			echo "Updates available for ${CMGS_CODE_DIR}/mangos-${1}. Run update-cmangos.sh script to update the codes."
		fi
	else
		echo "Folder ${CMGS_CODE_DIR}/mangos-${1} not available. Aborting checking operation!"
	fi
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
			check_update "$1"
		fi
	else
		echo "Not running Ubuntu 24.04/26.04 LTS distribution. Exiting..."
		exit;
	fi
else
	echo "Not running a distribution with /etc/os-release available"
	exit;
fi
