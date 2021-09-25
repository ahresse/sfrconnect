#!/bin/bash

# Auto-connect to SFR WiFi

# Usage: ./sfrconnect.sh <username> <password> 

# VARS
# EFFECTIVE_URL: URL associated with 302 reply (contains challenge)
# PORTAL_URL: target URL for POST
# challenge: part of POST data to be sent
# nasid: hotspot's MAC address (part of location)
# mac: client's MAC address (part of location)

USERNAME=${1}
PASSWORD=${2}
PORTAL_URL=https://hotspot.wifi.sfr.fr/nb4_crypt.php
SCRIPT_NAME=${0##*/}
TMP_DIR=/tmp/${SCRIPT_NAME}
DEBUG=1
LOG2FILE=1
LOG_FILE=/var/log/${SCRIPT_NAME}.log
CURRENT_DATE=`date +"%d/%m/%Y-%H:%M"`
TEST_URL="http://www.google.com/"
PORTAL_RETURN=${TMP_DIR}/portal_return

log2file () {
	if [ ${LOG2FILE} == 1 ]; then
		echo "${CURRENT_DATE},$1" >> ${LOG_FILE}
	fi
}

extract_url_param () {
	PARAM=$2
	URL_PARAMS=$(echo $1 | awk '{print f[split($1,f,"?")]}')

	PARAM_VAL=$(echo ${URL_PARAMS} ${PARAM} \
		| awk '{print f[split($1,f,$2"=")]}' \
		| awk 'BEGIN { FS="&" } {print $1}')
	echo ${PARAM_VAL}
}

# Check internet connection with curl redirection and store the effective url
EFFECTIVE_URL=$(curl -Ls -o /dev/null -w %{url_effective} ${TEST_URL})

if [[ "${EFFECTIVE_URL}" != "${TEST_URL}" ]]; then
	echo "Connecting..."
	log2file 0

	#Extract URL data
	CHALLENGE=$(extract_url_param ${EFFECTIVE_URL} challenge)
	NASID=$(extract_url_param ${EFFECTIVE_URL} nasid)
	MAC=$(extract_url_param ${EFFECTIVE_URL} mac)
	UAMPORT=$(extract_url_param ${EFFECTIVE_URL} uamport)
	UAMIP=$(extract_url_param ${EFFECTIVE_URL} uamip)
	MODE=$(extract_url_param ${EFFECTIVE_URL} mode)
	CHANNEL=$(extract_url_param ${EFFECTIVE_URL} channel)
	USERURL=$(extract_url_param ${EFFECTIVE_URL} userurl)

	# Debug info
	if [ ${DEBUG} == 1 ]; then
		echo DEBUG INFOS:
		echo "	challenge	${CHALLENGE}"
		echo "	nasid		${NASID}"
		echo "	mac		${MAC}"
		echo "	uamport		${UAMPORT}"
		echo "	uamip		${UAMIP}"
		echo "	mode		${MODE}"
		echo "	channel		${CHANNEL}"
		echo "	userurl		${USERURL}"
	fi

	# Prepare POST with target URL (set in the code)
	POST_DATA="choix=neuf&"`
		`"username=${USERNAME}&"`
		`"password=${PASSWORD}&"`
		`"conditions=on&"`
		`"challenge=${CHALLENGE}&"`
		`"username2=${USERNAME}&"`
		`"accessType=neuf&"`
		`"lang=fr&"`
		`"mode=${MODE}&"`
		`"userurl=${USERURL}&"`
		`"uamip=${UAMIP}&"`
		`"uamport=${UAMPORT}&"`
		`"channel=${CHANNEL}&"`
		`"mac=${NASID}|mac&connexion=Connexion"

	# Send POST request
	mkdir -p ${TMP_DIR}
	cd ${TMP_DIR}
	wget -O ${PORTAL_RETURN} ${PORTAL_URL} --post-data="${POST_DATA}"

	# We have to follow the returned window.location to finalize connexion
	CONNEXION_URL=$(grep window.location ${PORTAL_RETURN} | \
		awk 'BEGIN { FS = "\""} { print $2 }')
	wget -q ${CONNEXION_URL}
	
	# Wait for connexion to be effective
	sleep 2
	
	# Re-check internet connection
	EFFECTIVE_URL=$(curl -Ls -o /dev/null -w %{url_effective} ${TEST_URL})
fi

if [[ "${EFFECTIVE_URL}" == "${TEST_URL}" ]]; then
	echo "Internet OK"
	log2file 1
fi

