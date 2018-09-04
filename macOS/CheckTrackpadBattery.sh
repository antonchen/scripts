#!/bin/bash
# Create Date: 2017-05-26 17:03:49
# Last Modified: 2018-09-04 12:04:26
# Author: Anton Chen
# Email: contact@antonchen.com
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
system_profiler SPBluetoothDataType|sed -n '/Trackpad/,/Vendor ID/p'|grep -q 'Connected: Yes'
if [ $? -ne 0 ]; then
    echo "Trackpad 正在充电或未连接"
    exit
fi

batteryLevel=$(system_profiler SPBluetoothDataType|sed -n '/Trackpad/,/Vendor ID/p'|grep Battery|awk -F"[:| |%]+" '{print $4}')
if [ $batteryLevel -lt 20 ]; then
    osascript -e "tell application \"System Events\" to display notification \"电量低，剩余 $batteryLevel%\" with title \"Magic Trackpad 2\" sound name \"Submarine\""
fi
