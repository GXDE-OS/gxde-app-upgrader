#!/bin/bash
if [ "$(id -u)" != "0" ] ; then
	pkexec "$0" "$@"
	exit
fi
HERE=$(dirname $0)
mkdir /tmp/gxde-app-upgrader
trap "rm -f  /tmp/gxde-app-upgrader/upgradeStatus.txt" EXIT
source /opt/bashimport/transhell.sh
load_transhell_debug

function get_name_from_desktop_file() {
	local app_name_in_desktop
	local name_orig
	local name_i18n
	local package_name
	package_name=$1
    for desktop_file_path in $(dpkg -L "$package_name" |grep /usr/share/applications/ | awk '/\.desktop$/ {print}'); do
if [ "$(grep -m 1 '^NoDisplay=' "$desktop_file_path" | cut -d '=' -f 2)" = "true" ] ||  [ "$(grep -m 1 '^NoDisplay=' "$desktop_file_path" | cut -d '=' -f 2)" = "True" ];then
	continue
	else 
	name_orig=$(grep -m 1 '^Name=' "$desktop_file_path" | cut -d '=' -f 2)
    name_i18n=$(grep -m 1 "^Name\[${LANGUAGE}\]\=" "$desktop_file_path" | cut -d '=' -f 2)
		if [ -z "$name_i18n" ] ;then
		app_name_in_desktop=$name_orig
		else
		app_name_in_desktop=$name_i18n
		fi
	
	fi
    done
	for desktop_file_path in $(dpkg -L "$package_name" |grep /opt/apps/$package_name/entries/applications | awk '/\.desktop$/ {print}'); do
	if [ "$(grep -m 1 '^NoDisplay=' "$desktop_file_path" | cut -d '=' -f 2)" = "true" ] ||  [ "$(grep -m 1 '^NoDisplay=' "$desktop_file_path" | cut -d '=' -f 2)" = "True" ];then
	continue
	else 
	name_orig=$(grep -m 1 '^Name=' "$desktop_file_path" | cut -d '=' -f 2)
    name_i18n=$(grep -m 1 "^Name\[${LANGUAGE}\]\=" "$desktop_file_path" | cut -d '=' -f 2)
		if [ -z "$name_i18n" ] ;then
		app_name_in_desktop=$name_orig
		else
		app_name_in_desktop=$name_i18n
		fi
	
	fi
    done
if [ -z "$app_name_in_desktop" ] ;then
app_name_in_desktop=${package_name}
fi
echo ${app_name_in_desktop}

}
touch /tmp/gxde-app-upgrader/upgradeStatus.txt

# 执行 apt update
pkexec ${HERE}/gxde-do-upgrade-worker.sh update | zenity --progress --auto-close --pulsate --no-cancel --text="${TRANSHELL_CONTENT_UPDATE_CHEKING_PLEASE_WAIT}" --height 70 --width 400 --title="${TRANSHELL_CONTENT_UPGRADE_MODEL}" 

if [ -z `cat /tmp/gxde-app-update-status.txt` ] ; then
	${HERE}/gxde-do-upgrade-worker.sh clean-log
else
	zenity --error --text "${TRANSHELL_CONTENT_CHECK_UPDATE_PROCESS_ERROR_PRESS_CONFIRM_TO_CHECK}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 200 --width 350 
	zenity --text-info --filename=/tmp/gxde-app-update-log.txt --checkbox="${TRANSHELL_CONTENT_I_ALREDY_COPIED_THE_LOG_HERE_AND_WILL_USE_IT_TO_FEEDBACK}" --title="${TRANSHELL_CONTENT_FEEDBACK_CAN_BE_FOUND_IN_THE_SETTINGS}" 
	${HERE}/gxde-do-upgrade-worker.sh clean-log
    rm -f /tmp/gxde-app-upgrader/upgradeStatus.txt
	exit
fi

# 获取可更新应用列表
PKG_LIST="$(${HERE}/gxde-do-upgrade-worker.sh upgradable-list)"
## 如果没更新，就弹出不需要更新
if [ -z "$PKG_LIST" ] ; then
	zenity --info --text "${TRANSHELL_CONTENT_NO_NEED_TO_UPGRADE}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 150 --width 300 
else
	## 获取用户选择的要更新的应用
	### 指定分隔符为 \n
	IFS_OLD="$IFS"
	IFS=$'\n'

	PKG_UPGRADE_LIST=$(for line in $PKG_LIST ; do
	PKG_NAME=$(echo $line | awk -F ' ' '{print $1}')
	PKG_NEW_VER=$(echo $line | awk -F ' ' '{print $2}')
	PKG_CUR_VER=$(echo $line | awk -F ' ' '{print $3}')

# 	dpkg --compare-versions $PKG_NEW_VER le $PKG_CUR_VER
# 	if [ $? -eq 0 ] ; then
# 		continue
# 	fi
# 版本号相同也更新
	APP_NAME=$(get_name_from_desktop_file $PKG_NAME)
	#### 检测是否是 hold 状态
	PKG_STA=$(dpkg-query -W -f='${db:Status-Want}' $PKG_NAME)
	if [ "$PKG_STA" != "hold" ] ; then
		echo "true"
		echo "$APP_NAME"
		echo "$PKG_NEW_VER"
		echo "$PKG_CUR_VER"
		echo "$PKG_NAME"
	else
		echo "false"
		echo "$APP_NAME${TRANSHELL_CONTENT_CAN_NOT_UPGRADE_FOR_BEING_HOLD}"
		echo "$PKG_NEW_VER"
		echo "$PKG_CUR_VER"
		echo "$PKG_NAME"
	fi
done)

	### 还原分隔符
	IFS="$IFS_OLD"

	## 如果没有应用需要更新，则直接退出
	if [ -z "$PKG_UPGRADE_LIST" ] ; then
		zenity --info --text "${TRANSHELL_CONTENT_NO_NEED_TO_UPGRADE}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 150 --width 300 
	else
		PKG_UPGRADE_LIST=$(echo "$PKG_UPGRADE_LIST" | zenity --list --text="${TRANSHELL_CONTENT_CHOOSE_APP_TO_UPGRADE}" --column="${TRANSHELL_CONTENT_CHOOSE}" --column="${TRANSHELL_CONTENT_APP_NAME}" --column="${TRANSHELL_CONTENT_NEW_VERSION}" --column="${TRANSHELL_CONTENT_UPGRADE_FROM}" --column="${TRANSHELL_CONTENT_PKG_NAME}" --separator=" " --checklist --multiple --print-column=5 --height 350 --width 650 )
		## 如果没有选择，则直接退出
		if [ -z "$PKG_UPGRADE_LIST" ] ; then
			zenity --info --text "${TRANSHELL_CONTENT_NO_APP_IS_CHOSEN}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 150 --width 300 
		else
			### 更新用户选择的应用
	for PKG_UPGRADE in $PKG_UPGRADE_LIST;do
			APP_UPGRADE="$(get_name_from_desktop_file $PKG_UPGRADE)"
			update_transhell
			pkexec ${HERE}/gxde-do-upgrade-worker.sh upgrade-app $PKG_UPGRADE -y | zenity --progress --auto-close --no-cancel --pulsate --text="${TRANSHELL_CONTENT_UPGRADING_PLEASE_WAIT}" --height 70 --width 400 --title="${TRANSHELL_CONTENT_UPGRADE_MODEL}" 
	done
			#### 更新成功
			if [ -z "`cat /tmp/gxde-app-upgrade-status.txt`" ] ; then
				zenity --info --text "${TRANSHELL_CONTENT_CHOSEN_APP_UPGRADE_FINISHED}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 150 --width 300 
			else
			#### 更新异常
				zenity --error --text "${TRANSHELL_CONTENT_APP_UGRADE_PROCESS_ERROR_PRESS_CONFIRM_TO_CHECK}" --title "${TRANSHELL_CONTENT_UPGRADE_MODEL}" --height 200 --width 350 
				zenity --text-info --filename=/tmp/gxde-app-upgrade-log.txt --checkbox="${TRANSHELL_CONTENT_I_ALREDY_COPIED_THE_LOG_HERE_AND_WILL_USE_IT_TO_FEEDBACK}" --title="${TRANSHELL_CONTENT_FEEDBACK_CAN_BE_FOUND_IN_THE_SETTINGS}" 
			fi
		fi
	fi
fi

