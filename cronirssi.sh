#!/bin/sh
##############################################################################
#
# cronirssi.sh v1.02 (20151116)
#
# Copyright (c) 2015  Michael Hansen
#
# Permission to use, copy, modify, and distribute this software
# for any purpose with or without fee is hereby granted, provided
# that the above copyright notice and this permission notice
# appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
# WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL
# THE AUTHOR BE LIABLE FOR  ANY SPECIAL, DIRECT, INDIRECT, OR
# CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
##############################################################################
#
# shell script to configure and run screened irssi in crontab, edit CONFIG_
# variables as needed copy the script to a suitable place (like ~/bin/)
# and run the script without arguments for help
#
# quickstart:
#	to install a crontab entry with the current config: ./cronirssi.sh cron
#
# history:
#	v1.02 (20151116)
#		added license and copyright
#	v1.01 (20151116)
#		fixed cosmetic typo
#	v1.00 (20151116)
#		initial release
#
# download:
#	https://github.com/mh-source/cronirssi.sh
#

# if irssi isnt configured to autoconnect to a network, you want "-c <network>"
CONFIG_IRSSI_ARGS=""

# how often cron checks if irssi should be started, every X minutes  (1-59)
CONFIG_CRON_CHECK="10"

# you probably dont need to change the following
CONFIG_SCREEN_ARGS="-U -m -d"
CONFIG_SCREEN_NAME="irssi"
CONFIG_SCREEN_TERM="xterm"
CONFIG_SCREEN_SHELL="bash"
CONFIG_CRON_FILE="crontab.txt"

chmod u+x "${0}" # make sure we are executable in the future

if [ \( ${CONFIG_CRON_CHECK} -lt 1 \) -o \( ${CONFIG_CRON_CHECK} -gt 59 \) ]; then
	echo "${0}: CONFIG_CRON_CHECK invalid value (${CONFIG_CRON_CHECK})"
	exit 255
fi

if [ -z "${CONFIG_SCREEN_NAME}" ]; then
	echo "${0}: CONFIG_SCREEN_NAME not set"
	exit 255
fi

if [ -z "${CONFIG_SCREEN_TERM}" ]; then
	echo "${0}: CONFIG_SCREEN_TERM not set"
	exit 255
fi

if [ -z "${CONFIG_SCREEN_SHELL}" ]; then
	echo "${0}: CONFIG_SCREEN_SHELL not set"
	exit 255
fi

if [ -z "${CONFIG_CRON_FILE}" ]; then
	echo "${0}: CONFIG_CRON_FILE not set"
	exit 255
fi

FULLPATH="`(cd \`dirname \"${0}\"\` ; pwd)`"
BASENAME="`basename ${0}`"

CRON_FILE="${FULLPATH}/${CONFIG_CRON_FILE}"

if [ ${#} -eq 0 ]; then

	#
	# no arguments, print help
	#
	cat  "${0}" | grep "cronirssi.sh" | head -n 1 | cut -d " " -f 2-
	echo ""
	echo "	syntax: ${0} [del|check|cron|list]"
	echo ""
	echo "		del   - remove cron entry"
	echo "		check - used internally to check for and start screens"
	echo "		        run it manually to force a check"
	echo "		cron  - update crontab with configured settings"
	echo "		list  - list the current crontab"
	echo ""
	echo "	to changed settings, edit the top of ${0}"

else

	if [ ${#} -eq 1 ]; then

		case "${1}" in
			del )
				#
				# remove cron entry if exists
				#
				umask 077
				rm -rf "${CRON_FILE}"
				crontab -l 2> /dev/null | grep -v "${BASENAME}" > "${CRON_FILE}"
				crontab "${CRON_FILE}"
				rm -rf "${CRON_FILE}"
				echo "crontab updated, removed entry:"
				crontab -l
				;;

			check )
				#
				# check if screened irssi is running, otherwise start it
				#
				((screen -list | grep \.${CONFIG_SCREEN_NAME} | grep Detached || screen -list | grep \.${CONFIG_SCREEN_NAME} | grep Attached) > /dev/null || (screen -wipe ; screen -S ${CONFIG_SCREEN_NAME} -t ${CONFIG_SCREEN_NAME} ${CONFIG_SCREEN_ARGS} ${CONFIG_SCREEN_SHELL} --login -c "export TERM=\"${CONFIG_SCREEN_TERM}\"; irssi ${CONFIG_IRSSI_ARGS}")) 2>&1 > /dev/null
				;;

			cron )
				#
				# remove old cron entry if exists and create a new one
				#
				umask 077
				rm -rf "${CRON_FILE}"
				crontab -l 2> /dev/null | grep -v "${BASENAME}" > "${CRON_FILE}"
				echo "*/${CONFIG_CRON_CHECK} * * * * ${FULLPATH}/${BASENAME}" check > "${CRON_FILE}"
				crontab "${CRON_FILE}"
				rm -rf "${CRON_FILE}"
				echo "crontab updated, added entry:"
				crontab -l
				;;

			list )
				#
				# show the current crontab
				#
				echo "current crontab:"
				crontab -l
				;;

			* )
				#
				# unknown argument, print help
				#
				sh ${0}
				exit 255
				;;
		esac
	else
		#
		# more than one argument, print help
		#
		sh ${0}
		exit 255
	fi
fi

exit 0

##############################################################################
#
# eof cronirssi.sh
#
##############################################################################
