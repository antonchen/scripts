#!/bin/bash
# Create Date: 2017-05-26 17:03:49
# Last Modified: 2017-05-26 17:31:52
# Author: Anton Chen
# Email: contact@antonchen.com
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
system_profiler SPBluetoothDataType|grep -A 24 'Devices'|grep -q Trackpad
if [ $? -ne 0 ]; then
    echo "Trackpad 未连接"
    exit 1
fi

batteryLevel=$(system_profiler SPBluetoothDataType|grep -A 24 'Devices'|grep Battery|awk -F"[:| |%]+" '{print $4}')
if [ $batteryLevel -lt 20 ]; then
    osascript -e "tell application \"System Events\" to display notification \"电量低，剩余 $batteryLevel%\" with title \"Magic Trackpad 2\" sound name \"Submarine\""
fi
