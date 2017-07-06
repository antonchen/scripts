#!/bin/bash
# Create Date: 2017-07-05 20:00:46
# Last Modified: 2017-07-06 11:35:01
Version='v2.33'

read -p 'Server: ' server
read -p 'Port: ' port
read -p 'UUID: ' uuid
read -p 'Local Port: ' localPort

for key in server port uuid localPort; do
    res=$(eval echo '$'"$key")
    if [ "x$res" == "x" ]; then
        echo "[-] $key is null." >&2
        exit 2
    fi
done

wget --no-check-certificate -c -O v2ray-$Version-macos.zip https://github.com/v2ray/v2ray-core/releases/download/$Version/v2ray-macos.zip
if [ -f v2ray-$Version-macos.zip ]; then
    test -d v2ray-$Version-macos && rm -rf v2ray-$Version-macos
    if unzip v2ray-$Version-macos.zip; then
		sudo cp -f v2ray-$Version-macos/v2ray /usr/local/bin/v2ray
        sudo chmod +x /usr/local/bin/v2ray
        cp -f v2ray-$Version-macos/config.json $HOME/.v2ray-config.json
        rm -rf v2ray-$Version-macos.zip v2ray-$Version-macos
    else
        echo "[-] Unzip file failed, please check." >&2
        exit 2
    fi
else
    echo "[-] Download failed." >&2
    exit 2
fi

sed -i.bak "s/v2ray.cool/$server/g" $HOME/.v2ray-config.json
sed -i.bak "s/10086/$port/g" $HOME/.v2ray-config.json
sed -i.bak "s/a3482e88-686a-4a58-8126-99c9df64b7bf/$uuid/g" $HOME/.v2ray-config.json
sed -i.bak "s/1080/$localPort/g" $HOME/.v2ray-config.json
rm -f $HOME/.v2ray-config.json.bak

test -d $HOME/Library/LaunchAgents || mkdir -p $HOME/Library/LaunchAgents
cat > $HOME/Library/LaunchAgents/v2ray.plist << _LaunchAgents_
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>org.v2ray</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/bin/v2ray</string>
		<string>-config</string>
	    <string>$HOME/.v2ray-config.json</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>ServiceDescription</key>
	<string>V2Ray Client</string>
	<key>StandardErrorPath</key>
	<string>/tmp/v2ray.log</string>
	<key>StandardOutPath</key>
	<string>/tmp/v2ray.log</string>
</dict>
</plist>
_LaunchAgents_
ps -ef|grep -v grep|grep -q /usr/local/bin/v2ray
if [ $? -eq 0 ]; then
    launchctl unload $HOME/Library/LaunchAgents/v2ray.plist
fi
launchctl load $HOME/Library/LaunchAgents/v2ray.plist

echo "[+] V2ray client installed successfully, Socks 5 listen in localhost ${localPort}." >&2
