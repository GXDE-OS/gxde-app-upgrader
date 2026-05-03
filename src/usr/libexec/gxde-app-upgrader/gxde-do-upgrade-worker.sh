#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
if [[ $(command -v aptss) ]];then
APT_CMD=aptss
else
APT_CMD=/usr/bin/apt
fi

run_as_root() {
if [ "$(id -u)" != "0" ] ; then
	pkexec "$0" "$@"
	exit
fi
}

validate_package() {
if ! printf '%s\n' "$1" | grep -Eq '^[a-z0-9][a-z0-9+.-]+(:[a-z0-9]+)?$'; then
	echo "Invalid package name: $1" >&2
	exit 2
fi
}

validate_upgrade_args() {
PACKAGE_NAMES=()
ONLY_UPGRADE=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--only-upgrade)
			ONLY_UPGRADE="--only-upgrade"
			;;
		--*)
			echo "Unsupported option: $1" >&2
			exit 2
			;;
		*)
			validate_package "$1"
			PACKAGE_NAMES+=("$1")
			;;
	esac
	shift
done

if [ "${#PACKAGE_NAMES[@]}" -eq 0 ]; then
	echo "Missing package name" >&2
	exit 2
fi

if [ -z "$ONLY_UPGRADE" ]; then
	echo "Missing required --only-upgrade option" >&2
	exit 2
fi
}

write_upgrade_status() {
if [ -f /tmp/gxde-app-upgrade-log.txt ]; then
	grep '^E:' /tmp/gxde-app-upgrade-log.txt > /tmp/gxde-app-upgrade-status.txt || true
else
	: > /tmp/gxde-app-upgrade-status.txt
fi
}

download_to_cache() {
env LANGUAGE=en_US DEBIAN_FRONTEND=noninteractive ${APT_CMD} install -d -y --only-upgrade "${PACKAGE_NAMES[@]}" 2>&1 | tr '\r' '\n' | while IFS= read -r line; do
	printf '%s\n' "$line"
	speed=$(printf '%s\n' "$line" | sed -n 's/.*DL:\([^ ]*\).*/\1/p')
	progress=$(printf '%s\n' "$line" | sed -n 's/.*(\([0-9][0-9]*\)%).*/\1/p')
	if [ -n "$speed" ]; then
		echo "# Downloading packages... ${speed}"
	fi
	if [ -n "$progress" ]; then
		echo "$((progress * 80 / 100))"
	fi
done
return "${PIPESTATUS[0]}"
}

install_from_cache() {
echo "# Installing packages from cache..."
echo 85
env LANGUAGE=en_US DEBIAN_FRONTEND=noninteractive ${APT_CMD} install -y --no-download --only-upgrade "${PACKAGE_NAMES[@]}"
}


case $1 in 
	update)
	run_as_root "$@"
		env LANGUAGE=en_US ${APT_CMD} update 2>&1 | tee /tmp/gxde-app-update-log.txt
		IS_UPDATE_ERROR=`cat /tmp/gxde-app-update-log.txt | grep '^E:'`
		echo "$IS_UPDATE_ERROR" > /tmp/gxde-app-update-status.txt
		chmod 777 /tmp/gxde-app-update-status.txt
		chmod 777 /tmp/gxde-app-update-status.txt
	;;

	upgradable-list)
	run_as_root "$@"
		output=$(env LANGUAGE=en_US ${APT_CMD} list --upgradable | awk NR\>1)

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
	run_as_root "$@"
		shift
		validate_upgrade_args "$@"

		{
			download_to_cache
			download_ret="$?"
			if [ "$download_ret" -ne 0 ]; then
				exit "$download_ret"
			fi

			install_from_cache
			install_ret="$?"
			echo 100
			exit "$install_ret"
		} 2>&1 | tee /tmp/gxde-app-upgrade-log.txt
		ret=${PIPESTATUS[0]}
		chmod 777 /tmp/gxde-app-upgrade-log.txt
		write_upgrade_status
		if [ "$ret" -ne 0 ] || [ -s /tmp/gxde-app-upgrade-status.txt ]; then
			exit 1
		fi
	;;
	test-install-app)
	run_as_root "$@"
	validate_package "$2"

try_run_output=$(${APT_CMD} --dry-run install --only-upgrade "$2")
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
	try_run_output=$(${APT_CMD} --dry-run install --only-upgrade "$2")
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

	rm -f /tmp/gxde-app-update-status.txt /tmp/gxde-app-update-log.txt /tmp/gxde-app-upgrade-log.txt /tmp/gxde-app-upgrade-status.txt
	;;
esac
