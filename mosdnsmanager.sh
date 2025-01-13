#!/bin/bash

function CheckDependencies() {
    local DEPENDENCIES=(curl unzip systemd git go crontab)
    MISSING_DEPENDENCIES=()
    for i in "${DEPENDENCIES[@]}"; do
        if ! command -v $i &> /dev/null; then
            echo -e "\e[1;31mPlease install $i first.\e[0m"
            MISSING_DEPENDENCIES+=($i)
        fi
    done
    if [ ${#MISSING_DEPENDENCIES[@]} -ne 0 ]; then
        echo -e "\e[1;31mMissing dependencies: ${MISSING_DEPENDENCIES[@]}\e[0m"
        exit 1
    fi
}

function DownloadMosdns() {
    #get machine architecture
    ARCH=$(uname -m)
    TMPDIR=$(mktemp -d) || exit 1

    case $ARCH in
        x86_64)
            for i in {1..3}; do
            echo -e "\e[1;32mDownloading amd64 version mosdns...\e[0m"
            curl --connect-timeout 5 -m 10 --ipv4 -kfSLo "$TMPDIR/mosdns-linux-amd64.zip" "https://github.com/IrineSistiana/mosdns/releases/download/latest/mosdns-linux-amd64.zip"
                if [ $? -ne 0 ]; then
                    rm -f "$TMPDIR/mosdns-linux-amd64.zip"
                    echo -e "\e[1;31mDownload failed, retrying ($i/3)...\e[0m"
                else
                    break
                fi
            done
            ;;
        aarch64)
            for i in {1..3}; do
            echo -e "\e[1;32mDownloading arm64 version mosdns...\e[0m"
            curl --connect-timeout 5 -m 10 --ipv4 -kfSLo "$TMPDIR/mosdns-linux-amd64.zip" "https://github.com/IrineSistiana/mosdns/releases/download/latest/mosdns-linux-arm64.zip"
                if [ $? -ne 0 ]; then
                    rm -f "$TMPDIR/mosdns-linux-arm64.zip"
                    echo -e "\e[1;31mDownload failed, retrying ($i/3)...\e[0m"
                else
                    break
                fi
            done
            ;;
        *)
            echo -e "\e[1;31mUnsupported architecture: $ARCH\e[0m"
            exit 1
            ;;
    esac

    ZIPFILE=$(ls $TMPDIR | grep mosdns-linux)
    unzip $ZIPFILE -d /tmp/mosdns-binary
    mv /tmp/mosdns-binary/mosdns ./mosdns
    rm -rf /tmp/mosdns-binary
    rm -rf $TMPDIR
}

function FindMosdns() {
    #find local directory
    EXIST=$(find . -name mosdns)
    if [ -z $EXIST ]; then
        echo -e "\e[1;31mPlease place mosdns binary in the current directory and try again.\e[0m"
        exit 1
    fi
}

function InstallMosdns() {
    ARCH=$(uname -m)
    TMPDIR=$(mktemp -d) || exit 1

    for i in {1..3}; do
        echo -e "\e[1;32mClone v2dat from urlesistiana/v2dat\e[0m"
        git clone https://github.com/urlesistiana/v2dat.git "$TMPDIR/v2dat"
        if [ $? -ne 0 ]; then
            rm -rf "$TMPDIR/v2dat"
            echo -e "\e[1;31mClone failed, retrying ($i/3)...\e[0m"
        else
            break
        fi
    done
    
    # make v2dat
    go build -ldflags "-s -w" -trimpath -o "$TMPDIR/v2dat/v2dat" "$TMPDIR/v2dat"
    if [ $? -ne 0 ]; then
        echo -e "\e[1;31mBuild v2dat failed\e[0m"
        rm -rf "$TMPDIR"
        exit 1
    fi

    set -e
    echo -e "\e[1;32mInstalling mosdns...\e[0m"
    mv ./mosdns /usr/local/bin/mosdns
    chown root:root /usr/local/bin/mosdns
    chmod 755 /usr/local/bin/mosdns
    
    echo -e "\e[1;32mInstalling v2dat...\e[0m"
    mv "$TMPDIR/v2dat/v2dat" /usr/local/bin/v2dat
    chown root:root /usr/local/bin/v2dat
    chmod 755 /usr/local/bin/v2dat

    echo -e "\e[1;32mInstalling mosdnsmanager...\e[0m"
    cp ./mosdnsmanager.sh /usr/local/bin/mosdnsmanager
    chown root:root /usr/local/bin/mosdnsmanager
    chmod 755 /usr/local/bin/mosdnsmanager

    mkdir -p /etc/mosdns/geoip
    mv ./config.yaml.example /etc/mosdns/config.yaml
    mosdns service install -d /etc/mosdns/
    mkdir -p /etc/mosdns/hosts
    touch /etc/mosdns/hosts/hosts.txt
    echo -e "\e[1;32mMosdns installed.\e[0m"
}

function DownloadRules(){
    mkdir -p /usr/share/v2ray
    v2dat_dir="/usr/share/v2ray"
    TMPDIR=$(mktemp -d) || exit 1

    # BGP chnroute
    for i in {1..3}; do
        echo -e "\e[1;32mDownloading https://github.com/misakaio/chnroutes2/raw/refs/heads/master/chnroutes.txt\e[0m"
        curl --connect-timeout 5 -m 120 --ipv4 -kfSLo "$TMPDIR/geoip_cn.txt" "https://github.com/misakaio/chnroutes2/raw/refs/heads/master/chnroutes.txt"
        if [ $? -ne 0 ]; then
            rm -f "$TMPDIR/geoip_cn.txt"
            echo -e "\e[1;31mDownload failed, retrying ($i/3)...\e[0m"
        else
            break
        fi
    done
    echo -e "\e[1;32mDownload chnroutes successful\e[0m"

    # geosite.dat
    for i in {1..3}; do
        echo -e "\e[1;32mDownloading https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat\e[0m"
        curl --connect-timeout 5 -m 120 --ipv4 -kfSLo "$TMPDIR/geosite.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
        if [ $? -ne 0 ]; then
            rm -f "$TMPDIR/geosite.dat"
            echo -e "\e[1;31mDownload failed, retrying ($i/3)...\e[0m"
        else
            break
        fi
    done
    # checksum - geosite.dat
    for i in {1..3}; do
        echo -e "\e[1;32mDownloading https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat.sha256sum\e[0m"
        curl --connect-timeout 5 -m 10 --ipv4 -kfSLo "$TMPDIR/geosite.dat.sha256sum" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat.sha256sum"
        if [ $? -ne 0 ]; then
            rm -f "$TMPDIR/geosite.dat.sha256sum"
            echo -e "\e[1;31mDownload failed, retrying ($i/3)...\e[0m"
        else
            break
        fi
    done
    if [ "$(sha256sum "$TMPDIR/geosite.dat" | awk '{print $1}')" != "$(cat "$TMPDIR/geosite.dat.sha256sum" | awk '{print $1}')" ]; then
        echo -e "\e[1;31mgeosite.dat checksum error\e[0m"
        rm -rf "$TMPDIR"
        exit 1
    fi

    # clean and install dat file
    rm -rf "$TMPDIR"/*.sha256sum
    \cp -a "$TMPDIR"/*.dat /usr/share/v2ray/

    echo -e "\e[1;32mDownload rules successful, unpack geosite.dat\e[0m"

    # unpack geosite.dat and install rules
    v2dat unpack geosite -o /etc/mosdns/geoip/ -f cn $v2dat_dir/geosite.dat
    cp "$TMPDIR/geoip_cn.txt" /etc/mosdns/geoip/geoip_cn.txt
    rm -rf "$TMPDIR"
}

function UpdateRules() {
    TMPDIR=$(mktemp -d) || exit 1
    # BGP chnroute
    echo -e "\e[1;32mDownloading https://github.com/misakaio/chnroutes2/raw/refs/heads/master/chnroutes.txt\e[0m"
    curl --connect-timeout 5 -m 120 --ipv4 -kfSLo "$TMPDIR/geoip_cn.txt" "https://github.com/misakaio/chnroutes2/raw/refs/heads/master/chnroutes.txt"
    [ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1

    # geosite.dat
    echo -e "\e[1;32mDownloading https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat\e[0m"
    curl --connect-timeout 5 -m 120 --ipv4 -kfSLo "$TMPDIR/geosite.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    [ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1
    # checksum - geosite.dat
    echo -e "\e[1;32mDownloading https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat.sha256sum\e[0m"
    curl --connect-timeout 5 -m 10 --ipv4 -kfSLo "$TMPDIR/geosite.dat.sha256sum" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat.sha256sum"
    [ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1
    if [ "$(sha256sum "$TMPDIR/geosite.dat" | awk '{print $1}')" != "$(cat "$TMPDIR/geosite.dat.sha256sum" | awk '{print $1}')" ]; then
        echo -e "\e[1;31mgeosite.dat checksum error\e[0m"
        rm -rf "$TMPDIR"
        exit 1
    fi

    rm -rf "$TMPDIR"/*.sha256sum
    \cp -a "$TMPDIR"/*.dat /usr/share/v2ray/

    echo -e "\e[1;32mUpdate rules successful, unpack geosite.dat\e[0m"
    v2dat unpack geosite -o /etc/mosdns/geoip/ -f cn /usr/share/v2ray/geosite.dat
    cp "$TMPDIR/geoip_cn.txt" /etc/mosdns/geoip/geoip_cn.txt
    
    rm -rf "$TMPDIR"
}

function SetAutoUpdate() {
    echo -e "\e[1;32mSetting auto update rules...\e[0m"
    TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
    if [ "$TIMEZONE" == "UTC" ]; then
        CRON_TIME="20 16 * * *"
    elif [ "$TIMEZONE" == "Asia/Shanghai" ]; then
        CRON_TIME="0 4 * * *"
    else
        echo -e "\e[1;31mUnsupported timezone: $TIMEZONE\e[0m"
        exit 1
    fi
    echo "$CRON_TIME root /usr/local/bin/mosdnsmanager update -r" > /etc/cron.d/mosdns
    echo -e "\e[1;32mAuto update rules set.\e[0m"
}

case $1 in
    install)
        case $2 in
            -r|--release)
                CheckDependencies
                DownloadMosdns
                InstallMosdns
                DownloadRules
                ;;
            -m|--manual)
                CheckDependencies
                FindMosdns
                InstallMosdns
                DownloadRules
                ;;
            -a|--autoupdate)
                SetAutoUpdate
                ;;
            *)
                echo "Usage: $0 install {-r|--release} : Install mosdns from release."
                echo "Usage: $0 install {-m|--manual} : Install mosdns from local directory."
                echo "Usage: $0 install {-a|--autoupdate} : Set auto update rules."
                echo "Please run with root privilege."
                exit 1
                ;;
        esac
        ;;
    start)
        echo "Starting mosdns..."
        systemctl start mosdns
        echo "Mosdns started."
        ;;
    stop)
        echo "Stopping mosdns..."
        systemctl stop mosdns
        echo "Mosdns stopped."
        ;;
    restart)
        echo "Restarting mosdns..." 
        systemctl restart mosdns
        echo "Mosdns restarted."
        ;;
    update)
        case $2 in
            -r|--reboot)
                echo "Updating rules with reboot..."
                UpdateRules
                systemctl restart mosdns
                echo "Rules updated and applied."
                ;;
            -d|--dryrun)
                echo "Updating rules without reboot..."
                UpdateRules
                echo "Rules updated. Please restart mosdns service to apply rules."
                ;;
            *)
                echo "Usage: $0 update {-r|--reboot} : Update rules with reboot. Rules will be applied after service restart."
                echo "Usage: $0 update {-d|--dryrun} : Update rules without reboot. Rules will not be applied until service restart."
                echo "Please run with root privilege."
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 {install|start|stop|restart|update}"
        exit 1
        ;;
esac
