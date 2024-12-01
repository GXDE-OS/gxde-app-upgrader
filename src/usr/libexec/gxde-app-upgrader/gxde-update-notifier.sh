#!/bin/bash

HERE=$(dirname $0)
source /opt/bashimport/transhell.sh
load_transhell_debug

#############################################################

# 设置APT命令
if command -v aptss >/dev/null 2>&1; then
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

# 检测网络链接畅通（指数退避 + 最大重试次数）
function network-check() {
    local timeout=15
    local target="www.baidu.com"
    local max_wait_time=$((12 * 3600))  # 最大等待时间为12小时
    local max_retries=10  # 最大重试次数
    local wait_time=$timeout
    local ret_code
    local retries=0

    # 直到网络连接成功或者达到最大重试次数
    while :; do
        ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)
        if [ "$ret_code" = "200" ]; then
            return 0
        fi
        
        # 增加重试次数
        retries=$((retries + 1))
        if [ $retries -ge $max_retries ]; then
            echo "$TRANSHELL_CONTENT_NETWORK_FAIL"
            echo "Max retry attempts reached. Network check failed."
            return 1
        fi

        echo "$TRANSHELL_CONTENT_NETWORK_FAIL"
        echo "Retrying in ${wait_time} seconds... (Attempt $retries/$max_retries)"
        sleep $wait_time

        # 每次重试等待时间翻倍
        wait_time=$((wait_time * 2))
        if [ $wait_time -gt $max_wait_time ]; then
            wait_time=$max_wait_time
        fi
    done
}

# 执行网络检查
network-check
if [ $? -ne 0 ]; then
    exit 1
fi

# 更新源文件
/usr/bin/apt update
${APT_CMD} update

updatetext=$(LANGUAGE=en_US ${APT_CMD} update 2>&1)

# 错误检查：直到APT更新成功
max_retries=10  # 最大重试次数
retries=0
until [ -z "$(echo $updatetext | grep 'E: ')" ]; do
    if [ $retries -ge $max_retries ]; then
        echo "${TRANSHELL_CONTENT_UPDATE_ERROR_AND_WAIT_15_SEC}"
        echo "Max retry attempts reached for apt update. Exiting."
        exit 1
    fi

    echo "${TRANSHELL_CONTENT_UPDATE_ERROR_AND_WAIT_15_SEC}"
    sleep 15
    updatetext=$(LANGUAGE=en_US ${APT_CMD} update 2>&1)
    retries=$((retries + 1))
done

# 获取可升级包的数量
update_app_number=$(${APT_CMD} list --upgradable 2>/dev/null | grep -c upgradable)

if [ "$update_app_number" -le 0 ]; then
    exit 0
fi

# 获取用户选择的要更新的应用
PKG_LIST="$(${HERE}/gxde-do-upgrade-worker.sh upgradable-list)"

# 保存旧的IFS值并设定新的分隔符为换行符
IFS_OLD="$IFS"
IFS=$'\n'

# 检查每个包的升级状态
for line in $PKG_LIST; do
    PKG_NAME=$(echo $line | awk '{print $1}')
    PKG_NEW_VER=$(echo $line | awk '{print $2}')
    PKG_CUR_VER=$(echo $line | awk '{print $3}')

    # 检测是否是 hold 状态
    PKG_STA=$(dpkg-query -W -f='${db:Status-Want}' $PKG_NAME)
    if [ "$PKG_STA" = "hold" ]; then
        let update_app_number=$update_app_number-1
        echo "$PKG_NAME is held. Let number -1"
    else
        echo "$PKG_NAME is checked upgradable."
    fi
done

# 恢复IFS为原始值
IFS="$IFS_OLD"

# 如果没有需要更新的包，直接退出
if [ $update_app_number -le 0 ]; then
    exit 0
fi

# 更新Transhell
update_transhell

# 检查用户是否禁用通知
user=$(who | awk '{print $1}' | head -n 1)
if [ -e "/home/$user/.config/deepin/disable-gxde-update-notifier" ]; then
    echo "User has disabled upgrade notifications."
    echo "User doesn't want to be at the top of the world."
    exit 0
else
    # 发送升级通知
    notify-send -a gxde-deb-installer "${TRANSHELL_CONTENT_GXDE_UPGRADE_NOTIFY}" "${TRANSHELL_CONTENT_THERE_ARE_APPS_TO_UPGRADE}"
fi
