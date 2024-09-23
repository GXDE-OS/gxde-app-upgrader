#!/bin/bash

if [[ $(command -v aptss) ]];then
APT_CMD=aptss
else
APT_CMD=/usr/bin/apt
fi


case $1 in 
	update)
if [ "$(id -u)" != "0" ] ; then
	pkexec "$0" "$@"
	exit
fi
		env LANGUAGE=en_US ${APT_CMD} update 2>&1 | tee /tmp/gxde-app-update-log.txt
		IS_UPDATE_ERROR=`cat /tmp/gxde-app-update-log.txt | grep "E: "`
		echo "$IS_UPDATE_ERROR" > /tmp/gxde-app-update-status.txt
		chmod 777 /tmp/gxde-app-update-status.txt
		chmod 777 /tmp/gxde-app-update-status.txt
	;;

	upgradable-list)
		output=$(env LANGUAGE=en_US /usr/bin/apt  -c /opt/durapps/spark-store/bin/apt-fast-conf/aptss-apt.conf list --upgradable | awk NR\>1)

		IFS_OLD="$IFS"
		IFS=$'\n'

		for line in $output ; do
			PKG_NAME=$(echo $line | awk -F '/' '{print $1}')
			PKG_NEW_VER=$(echo $line | awk -F ' ' '{print $2}')
			PKG_CUR_VER=$(echo $line | awk -F ' ' '{print $6}' | awk -F ']' '{print $1}')
			echo "${PKG_NAME} ${PKG_NEW_VER} ${PKG_CUR_VER}"
		done

		IFS="$IFS_OLD"
	;;

	upgrade-app)
if [ "$(id -u)" != "0" ] ; then
	pkexec "$0" "$@"
	exit
fi

		env LANGUAGE=en_US ${APT_CMD} install "${@:2}" --only-upgrade  2>&1 | tee /tmp/gxde-app-upgrade-log.txt
		chmod 777 /tmp/gxde-app-upgrade-log.txt
		IS_UPGRADE_ERROR=`cat /tmp/gxde-app-upgrade-log.txt | grep "Package manager quit with exit code."`
		echo "$IS_UPGRADE_ERROR" > /tmp/gxde-app-upgrade-status.txt
	;;
	test-install-app)
if [ "$(id -u)" != "0" ] ; then
	pkexec "$0" "$@"
	exit
fi

try_run_output=$(${APT_CMD} --dry-run install $2)
try_run_ret="$?"

if [ "$try_run_ret" -ne 0 ]
  then
    echo "Package manager quit with exit code.Here is the log" 
    echo "包管理器以错误代码退出.日志如下" 
    echo
    echo -e "${try_run_output}"
    echo "Will try after run ${APT_CMD} update"
    echo "将会在${APT_CMD} update之后再次尝试"
    ${APT_CMD} update
    echo ----------------------------------------------------------------------------
	try_run_output=$(${APT_CMD} --dry-run install $2)
	try_run_ret="$?"
  		if [ "$try_run_ret" -ne 0 ]
  		then
  		  echo "Package manager quit with exit code.Here is the log" 
   		 echo "包管理器以错误代码退出.日志如下" 
   		 echo
    		echo -e "${try_run_output}"
    		exit "$try_run_ret"
 		 fi

fi
	exit 0
	;;
	
	clean-log)

	rm -f /tmp/gxde-app-ssupdate-status.txt /tmp/gxde-app-ssupdate-log.txt /tmp/gxde-app-upgrade-log.txt /tmp/gxde-app-upgrade-status.txt
	;;
esac
