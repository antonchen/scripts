#!/bin/bash
# File: InitializationCentOS.sh
# Usage:  ./InitializationCentOS.sh
# Description: Initialization CentOS 6.x and CentOS 7.x.
# Version: 0.4
# Create Date: 2015-8-5 09:42
# Last Modified: 2019-06-10 19:46:31
# Author: Anton Chen
# Email: contact@antonchen.com
Dir="$(cd `dirname $0`&&pwd)"
IP_API='https://api.ip.sb/geoip'

# Check user
if [ $UID -ne 0 ]; then
    echo "Error: This script must be run as root." 1>&2
    exit 1
fi

# Check System version
if grep -iq ' 6\.[0-9].*' /etc/redhat-release ; then
    export OSVersion=6
elif grep -iq ' 7\.[0-9].*' /etc/redhat-release ; then
    export OSVersion=7
else
    echo "Error: Not getting system version."
    exit 2
fi

# Check IaaS
if grep -q ucloud /etc/yum.repos.d/CentOS-Base.repo ; then
    IaaS=uCloud
elif grep -q aliyuncs /etc/yum.repos.d/CentOS-Base.repo ; then
    IaaS=Aliyun
elif grep -q tencentyun /etc/yum.repos.d/CentOS-Base.repo ; then
    IaaS=tCloud
else
    IaaS=False
fi

# Check network
if [[ $(curl -Is -k --connect-timeout 5 -m 5 https://www.bing.com/ | head -n 1) =~ "200 OK" ]]; then
    Network=True
    IPInfo=$(curl -s -k --connect-timeout 5 -m 5 "${IP_API}")
    [[ "x$IPInfo" == "x" ]] && IPInfo="$(echo -e 'continent_code=AS\ncountry_code=CN')"
    echo "$IPInfo"|grep -q "continent_code.*AS"
    if [ $? -eq 0 ]; then
        Asia=True
        echo "$IPInfo"|grep -q "country_code.*CN"
        if [ $? -eq 0 ]; then
            CN=True
        else
            CN=False
        fi
    else
        Asia=False
    fi
else
    Network=False
fi

# Definition NTPServer
if [ "x$NTPServer" == "x" ] && [ "$CN" == "True" ]; then
    NTPServer='time5.aliyun.com'
elif [ "x$NTPServer" == "x" ] && [ "$Asia" == "True" ]; then
    NTPServer='time.asia.apple.com'
elif [ "x$NTPServer" == "x" ] && [ "$Asia" == "False" ]; then
    NTPServer='time.apple.com'
fi

success ()
{
    echo -ne "\033[60G[\033[32m  OK  \033[0m]\r"
    return 0
}

failure ()
{
    echo -ne "\033[60G[\033[31mFAILED\033[0m]\r"
    return 1
}

CheckStatus ()
{
    local RETVAL=$?
    echo -n "$@ "
    if [ $RETVAL -eq 0 ]; then
        success
    else
        failure
    fi
    echo
    return $RETVAL
}

InstallBaseTools ()
{
    local RPMList
    curl -s -I -k --connect-timeout 3 $(egrep '^baseurl=|^mirrorlist=' /etc/yum.repos.d/CentOS-Base.repo|head -1|awk -F= '{print $2}') > /dev/null 2>&1 || return
    rpm -qa | grep -v 'vim-' > /tmp/local-rpm.txt
    if ! grep -q 'epel' /etc/yum.repos.d/* ; then
        echo -n "Install epel-release "
        yum install -y epel-release > /dev/null 2>&1
        CheckStatus
    fi

    if [ "$IaaS" == "False" ] && [ "$CN" == "True" ]; then
        test -f /etc/yum.repos.d/epel.repo && rm -f /etc/yum.repos.d/epel.repo
        which curl > /dev/null 2>&1 || yum -y install curl > /dev/null 2>&1
        curl -sko /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-$OSVersion.repo
        sed -i '/aliyuncs/d' /etc/yum.repos.d/epel.repo
    fi
    
    if [ $OSVersion -eq 6 ]; then
        RPMList="acpid openssh-clients cronie ntpdate logrotate bash-completion vim-enhanced wget rsync tmpwatch tree lrzsz lsof screen sshpass telnet nc nmap bind-utils iftop iotop expect unzip setuptool system-config-network-tui htop"
    elif [ $OSVersion -eq 7 ]; then
        RPMList="acpid openssh-clients cronie chrony logrotate bash-completion vim-enhanced wget rsync tmpwatch tree lrzsz lsof screen yum-utils sshpass telnet nc nmap bind-utils iftop iotop expect unzip htop"
    fi
    for rpm in $RPMList;do
        grep -q "$rpm-" /tmp/local-rpm.txt && continue
        echo -n "Install $rpm "
        yum -y install $rpm > /dev/null 2>&1;
        CheckStatus
    done
    rm -f /tmp/local-rpm.txt
}

SetShell ()
{
    # Bash Shell
    sed -i '/HISTTIMEFORMAT=/d' /etc/bashrc
    sed -i '/HISTFILESIZE=/d' /etc/bashrc
    sed -i '/HISTSIZE=/d' /etc/bashrc

    echo -e "\nshopt -s histappend" >> /etc/bashrc
    echo "export HISTFILESIZE=100000" >> /etc/bashrc
    echo "export HISTSIZE=1000" >> /etc/bashrc
    echo "export HISTTIMEFORMAT=\"%F %T \"" >> /etc/bashrc

    chattr +a /root/.bash_history

    # Disable 'You have new mail in /var/spool/mail/root'
    echo 'unset MAILCHECK' >> /etc/profile
    # Disable cron send mail
    if ! grep -q '\-m off' /etc/sysconfig/crond; then 
        source /etc/sysconfig/crond && ([[ "x$CRONDARGS" == "x" ]] && sed -i 's/^CRONDARGS=.*$/CRONDARGS="-m off"/g' /etc/sysconfig/crond || sed -i "s/^CRONDARGS=.*$/CRONDARGS=\"-m off $CRONDARGS\"/g" /etc/sysconfig/crond)
    fi

    # Edit
    sed -i '/EDITOR/d' /etc/environment
    echo 'export EDITOR=vim' >> /etc/environment
}

SetTime ()
{
    #Set timezone
    test -f /etc/timezone && rm -f /etc/timezone
    if [ $OSVersion -eq 6 ]; then
        touch /etc/sysconfig/clock
        sed -i '/^ZONE=/d' /etc/sysconfig/clock
        echo 'ZONE="PRC"' >> /etc/sysconfig/clock
        test -f /etc/localtime && rm -f /etc/localtime
        cp -f /usr/share/zoneinfo/PRC /etc/localtime
    elif [ $OSVersion -eq 7 ]; then
        timedatectl set-local-rtc 0
        timedatectl set-timezone PRC
        touch /etc/sysconfig/clock
        sed -i '/^UTC=/d' /etc/sysconfig/clock
        echo 'UTC=true' >> /etc/sysconfig/clock
    fi

    if [ "$Network" == "True" ] && ([ "$IaaS" == "False" ] || [ "$IaaS" == "tCloud" ]); then
        touch /var/spool/cron/root
        if [ $OSVersion -eq 6 ]; then
            sed -i '/ntpdate/d' /var/spool/cron/root
            echo "*/5 * * * * ntpdate $NTPServer > /dev/null 2>&1" >> /var/spool/cron/root
        elif [ $OSVersion -eq 7 ]; then
            grep -q "$NTPServer" /etc/chrony.conf || (echo -e "server $NTPServer iburst\ndriftfile /var/lib/chrony/drift\nmakestep 1.0 3\nrtcsync\nlogdir /var/log/chrony" > /etc/chrony.conf)
        fi
    fi

    # Check crond
    if [ $OSVersion -eq 6 ]; then
        chkconfig crond on
        /etc/init.d/crond restart
    elif [ $OSVersion -eq 7 ]; then
        systemctl enable chronyd.service
        systemctl restart chronyd.service
    fi
}

DisableSE ()
{
    if [ -f /etc/selinux/config ]; then
        sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
        setenforce 0
    fi
}

DisableIPv6 ()
{
    if [ $OSVersion -eq 6 ]; then
        sed -i '/NETWORKING_IPV6/d' /etc/sysconfig/network
        echo "NETWORKING_IPV6=off" >> /etc/sysconfig/network
        if grep -q 'ipv6.disable' /boot/grub/grub.conf; then
            sed -i 's/ipv6.disable=[0-9]/ipv6.disable=1/g' /boot/grub/grub.conf
        else
            sed -i 's/\(kernel.*ro \)/\1ipv6.disable=1 /g' /boot/grub/grub.conf
        fi
    elif [ $OSVersion -eq 7 ]; then
        if grep -q 'ipv6.disable' /etc/default/grub; then
            sed -i 's/ipv6.disable=[0-9]/ipv6.disable=1/g' /etc/default/grub
        else
            sed -i '/GRUB_CMDLINE_LINUX/ s/="/="ipv6.disable=1 /' /etc/default/grub
        fi
        grub2-mkconfig -o /boot/grub2/grub.cfg

        if ! grep -q '\-4' /etc/sysconfig/chronyd; then 
            source /etc/sysconfig/chronyd && ([[ "x$OPTIONS" == "x" ]] && sed -i 's/^OPTIONS=.*$/OPTIONS="-4"/g' /etc/sysconfig/chronyd || sed -i "s/^OPTIONS=.*$/OPTIONS=\"-4 $OPTIONS\"/g" /etc/sysconfig/chronyd)
        fi
    fi
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
}

DisableFirewall ()
{
    if [ -f /etc/init.d/iptables ]; then
        iptables -Z
        iptables -X
        iptables -F
        /etc/init.d/iptables save >/dev/null 2>&1
        /etc/init.d/iptables stop >/dev/null 2>&1
    elif [ -f /usr/lib/systemd/system/firewalld.service ]; then
        systemctl stop  firewalld.service >/dev/null 2>&1
        systemctl disable firewalld.service >/dev/null 2>&1
    fi
}

SetSysctl ()
{

Parameter="# Set ARP
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
# Set TCP Memory
net.core.rmem_default = 2097152
net.core.wmem_default = 2097152
net.core.rmem_max = 4194304
net.core.wmem_max = 4194304
net.ipv4.tcp_rmem = 4096 8192 4194304
net.ipv4.tcp_wmem = 4096 8192 4194304
net.ipv4.tcp_mem = 524288 699050 1048576
# Set TCP SYN
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 16384
# Set TIME_WAIT
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_fin_timeout = 2
net.ipv4.ip_local_port_range = 1024 65535
# Set TCP keepalive
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
# Set Other TCP
net.ipv4.tcp_max_orphans = 65535
net.core.somaxconn = 16384
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
# Set Max map
vm.max_map_count = 655350
# Other
vm.swappiness = 0"

    Options="$(echo "$Parameter"|grep -v '# '|awk -F' = ' '{print $1}')"
    for Option in $Options; do
        sed -i "/$Option/d" /etc/sysctl.conf
    done
    sed -i '/# Set/d' /etc/sysctl.conf

    grep -q '# Anton modify' /etc/sysctl.conf || echo -e "\n# Anton modify $(date +%F)" >> /etc/sysctl.conf
    echo "$Parameter" >> /etc/sysctl.conf

    sysctl -p 1> /dev/null
    return 0
}

SetBootService ()
{
    if [ $OSVersion -eq 6 ]; then
        for offservice in $(chkconfig --list|grep "3:on"|awk '{print $1}'|egrep -v "crond|network|sshd|syslog|rsyslog|acpid"); do
            chkconfig $offservice off
            /etc/init.d/$offservice stop
        done

        chkconfig acpid on
        /etc/init.d/acpid start
    elif [ $OSVersion -eq 7 ]; then
        chmod +x /etc/rc.d/rc.local
        DisableService="$(systemctl list-unit-files --type=service|grep enabled|egrep -v "acpid.service|autovt@.service|crond.service|dbus-org.freedesktop.nm-dispatcher.service|getty@.service|irqbalance.service|microcode.service|rsyslog.service|sshd.service|chronyd.service|systemd-readahead-collect.service|systemd-readahead-drop.service|systemd-readahead-replay.service"|awk '{print $1}')"

        for offservice in $DisableService; do
            systemctl stop $offservice
            systemctl disable $offservice
        done

        for nic_name in $(ls /sys/class/net); do
            NIC_CONF="/etc/sysconfig/network-scripts/ifcfg-$nic_name"
            [[ "$nic_name" == "lo" ]] && continue
            grep -q "NAME" $NIC_CONF || echo "NAME=\"$nic_name\"" >> $NIC_CONF
            grep -q "DEVICE" $NIC_CONF || echo "DEVICE=\"$nic_name\"" >> $NIC_CONF
            sed -i '/NM_CONTROLLED/d' $NIC_CONF
            echo 'NM_CONTROLLED="no"' >> $NIC_CONF
        done

        chkconfig network on

        systemctl enable acpid.service
        systemctl start acpid.service
    fi
}

SetSSHD ()
{
    #Set SSHD
    Options="PermitEmptyPasswords UseDNS GSSAPIAuthentication"
    for Option in $Options ; do
        sed -i "/$Option/d" /etc/ssh/sshd_config
    done
    grep -q '# Anton modify' /etc/ssh/sshd_config || echo -e "\n# Anton modify $(date +%F)" >> /etc/ssh/sshd_config
    echo -e "PermitEmptyPasswords no\nUseDNS no\nGSSAPIAuthentication no" >> /etc/ssh/sshd_config

    if [ $OSVersion -eq 6 ]; then
        /etc/init.d/sshd reload
    elif [ $OSVersion -eq 7 ]; then
        systemctl restart sshd.service
    fi
}

SetLANG ()
{
    if [ $OSVersion -eq 6 ]; then
        sed -i '/LANG/d' /etc/sysconfig/i18n
        sed -i '/LC_ALL/d' /etc/sysconfig/i18n
        echo -e "LANG=\"en_US.UTF-8\"" >> /etc/sysconfig/i18n
    elif [ $OSVersion -eq 7 ]; then
        localectl set-locale LANG=en_US.UTF-8
    fi
}

SetLimit ()
{
    local FileMax
    FileMax=$(cat /proc/sys/fs/file-max)
    NrOpen=$(cat /proc/sys/fs/nr_open)
    if [ $FileMax -lt 655350 ]; then
        sed -i '/fs.file-max/d' /etc/sysctl.conf
        echo 'fs.file-max = 655350' >> /etc/sysctl.conf
        sysctl -p 1> /dev/null
        FileMax=645350
    elif [ $FileMax -gt $NrOpen ]; then
        FileMax=$(($NrOpen-5000))
    else
        FileMax=$(($FileMax-5000))
    fi
    if [ $OSVersion -eq 6 ]; then
        sed -i '/nofile/d' /etc/security/limits.conf
        echo "*               -       nofile          $FileMax" >> /etc/security/limits.conf
        sed -i 's#1024#unlimited#g' /etc/security/limits.d/90-nproc.conf
    elif [ $OSVersion -eq 7 ]; then
        sed -i '/nofile/d' /etc/security/limits.conf
        echo "*               -       nofile          $FileMax" >> /etc/security/limits.conf
        sed -i 's#4096#unlimited#g' /etc/security/limits.d/20-nproc.conf
        sed -i '/^DefaultLimitCORE/d' /etc/systemd/system.conf
        sed -i '/^DefaultLimitNOFILE/d' /etc/systemd/system.conf
        sed -i '/^DefaultLimitNPROC/d' /etc/systemd/system.conf
        echo -e "DefaultLimitCORE=infinity\nDefaultLimitNOFILE=$FileMax\nDefaultLimitNPROC=$FileMax" >> /etc/systemd/system.conf
    fi
}

ReloadConf ()
{
    if [ $OSVersion -eq 6 ]; then
        /etc/init.d/crond restart
        /etc/init.d/rsyslog restart
    else
        systemctl restart crond.service
        systemctl restart rsyslog.service
    fi
}

InitIaaS ()
{
    if [ "$IaaS" == "False" ]; then
        return
    elif [ "$IaaS" != "tCloud" ] && [ $OSVersion -eq 6 ]; then
        /etc/init.d/ntpd start
        chkconfig ntpd on
    elif [ "$IaaS" != "tCloud" ] && [ $OSVersion -eq 7 ]; then
        systemctl enable ntpd
        systemctl start ntpd
    fi

    if [ "$IaaS" == "Aliyun" ]; then
        if [ -f /etc/init.d/aegis ]; then
            /etc/init.d/aegis stop
            /etc/init.d/aegis uninstall
            rm -f /etc/init.d/aegis
        fi

        command -v systemctl > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            systemctl disable aliyun.service
            systemctl status aliyun.service
            rm -f /etc/systemd/system/aliyun.service
        fi

        for ((var=2; var<=5; var++)) do
            if [ -d "/etc/rc${var}.d/" ];then
                    rm -f "/etc/rc${var}.d/S80aegis"
            elif [ -d "/etc/rc.d/rc${var}.d" ];then
                rm -f "/etc/rc.d/rc${var}.d/S80aegis"
            fi
        done

        process='aegis_update aegis_cli aegis_client aegis_quartz'
        for i in ${process}; do
            killall -9 $i > /dev/null 2>&1
        done

        test -f /usr/sbin/aliyun-service && rm -f /usr/sbin/aliyun-service
        test -e /usr/local/aegis && rm -rf /usr/local/aegis

    elif [ "$IaaS" == "tCloud" ]; then
        test -e /usr/local/sa && rm -rf /usr/local/sa
        test -e /usr/local/agenttools && rm -rf /usr/local/agenttools
        test -e /usr/local/qcloud && rm -rf /usr/local/qcloud

        sed -i '/\/qcloud/d' /etc/rc.local /var/spool/cron/root

        process='sap100 secu-tcs-agent sgagent64 barad_agent agent agentPlugInD pvdriver'
        for i in ${process}; do
            killall -9 $i > /dev/null 2>&1
        done
    fi
}

InstallBaseTools
SetShell
SetTime
DisableSE
DisableFirewall
SetSysctl
# DisableIPv6
SetBootService
SetSSHD
SetLANG
SetLimit
ReloadConf
InitIaaS
echo -e "\n\033[32mInitialization completes, strongly recommends restarting the system.\033[0m"
