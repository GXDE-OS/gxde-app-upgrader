#!/bin/bash

HERE=$(dirname $0)
source /opt/bashimport/transhell.sh
load_transhell_debug

#############################################################
if [[ $(command -v aptss) ]];then
APT_CMD=aptss
else
APT_CMD=/usr/bin/apt
fi

# 发送通知
function notify-send() {
    local user=$(who | awk '{print $1}' | head -n 1)
    local uid=$(id -u $user)
    sudo -u $user DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${uid}/bus notify-send "$@"
}

# 检测网络链接畅通
function network-check() {
    local timeout=15
    local target=www.baidu.com
    local ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)

    if [ "x$ret_code" = "x200" ] ; then
        return 0
    else
        return 1
    fi
}

network-check
if [ $? -ne 0 ] ; then
    echo "$TRANSHELL_CONTENT_NETWORK_FAIL"
    exit -1
fi

# 每日更新源文件
${APT_CMD} update

updatetext=$(LANGUAGE=en_US ${APT_CMD} update 2>&1)

until [ "$(echo $updatetext | grep 'E: ')" = "" ]; do
    echo "${TRANSHELL_CONTENT_UPDATE_ERROR_AND_WAIT_15_SEC}"
    sleep 15
    updatetext=$(LANGUAGE=en_US ${APT_CMD} update 2>&1)
done

# 获取可升级包的数量
update_app_number=$(LANGUAGE=en_US ${APT_CMD} list --upgradable 2>/dev/null | grep -c upgradable)

if [ "$update_app_number" -le 0 ] ; then
    exit 0
fi

## 获取用户选择的要更新的应用
PKG_LIST="$(${HERE}/gxde-do-upgrade-worker.sh upgradable-list)"

IFS_OLD="$IFS"
IFS=$'\n'

for line in $PKG_LIST; do
    PKG_NAME=$(echo $line | awk '{print $1}')
    PKG_NEW_VER=$(echo $line | awk '{print $2}')
    PKG_CUR_VER=$(echo $line | awk '{print $3}')

    ## 检测是否是 hold 状态
    PKG_STA=$(dpkg-query -W -f='${db:Status-Want}' $PKG_NAME)
    if [ "$PKG_STA" = "hold" ]; then
        let update_app_number=$update_app_number-1
        echo "$PKG_NAME is held. Let number -1"
    else
        echo "$PKG_NAME is checked upgradable."
    fi
done

IFS="$IFS_OLD"

if [ $update_app_number -le 0 ] ; then
    exit 0
fi

update_transhell

user=$(who | awk '{print $1}' | head -n 1)
if [ -e "/home/$user/.config/deepin/disable-gxde-update-notifier" ]; then
    echo "他不想站在世界之巅，好吧"
    echo "Okay he doesn't want to be at the top of the world, okay"
    exit
else
    notify-send -a gxde-deb-installer "${TRANSHELL_CONTENT_GXDE_UPGRADE_NOTIFY}" "${TRANSHELL_CONTENT_THERE_ARE_APPS_TO_UPGRADE}"
fi
