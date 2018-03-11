#!/bin/bash
#
# Description: Install script to install NEM Infrastuctrure Server on Centos 7. Will also bootstrap, set log cleaning and add possibility
#              control NIS using Centos systemtools (systemctl)
# Details:
# * Creates user "nemnis" (system account, no login, no password)
# * Downloads latest NIS and bootstrap file
# * Uses /opt/nemnis as home directory, creates symlink nis_latest and is referred in systemctl conf file
# * NIS configuration (config-user.properties) in /opt/nemnis/nem directory => no need to update/replace/reconfigure configuration when NIS is updated
# * Places simple logrotate script to cron daily
# * Creates configuration file for Centos firewall (allows port 7890 in)

# NIS upgrade (example number only!, also "nemnis" might be different if you changed user from script):
# tar xzf nis-0.7.70.tgz -C /opt/nemnis
# mkdir /opt/nemnis/nis-0.7.70
# mv /opt/nemnis/package/* /opt/nemnis/nis-0.7.70
# rm -rf /opt/nemnis/nis_latest
# ln -s /opt/nemnis/nis-0.7.70 /opt/nemnis/nis_latest

# After above, run "systemctl stop nis" and "systemctl start nis"

if [ "$EUID" -ne 0 ]
  then echo -e "\033[31mPlease run as root\033[m"
  exit
fi
MISSINGPROGS=""
if [ ! -f /usr/bin/curl ]; then
    MISSINGPROGS="${MISSINGPROGS} curl"
fi

if [ ! -f /usr/bin/unzip ]; then
   MISSINGPROGS="${MISSINGPROGS} unzip"
fi

if [ ! -f /usr/bin/java ]; then
    MISSINGPROGS="${MISSINGPROGS} java"
fi

if [ ${#MISSINGPROGS} -gt 2 ]; then
    echo -e "Following programs missing: $MISSINGPROGS"
    echo -e "Aborting..."
    exit
fi

echo -e "\033[32m*\033[m Checking latest NIS version and getting latest bootstrap file"
NEMUSER=nemnis
NISVER=$(curl -s http://bob.nem.ninja/version.txt)
DBVER=""
htmltext=$(curl -s "http://bob.nem.ninja" --list-only | sed -e 's/<[^>]*>/ /g' | grep db.zip | grep -v db.zip.sig)
set -- junk $htmltext
shift
for word; do
if [[ $word = *"db.zip"* ]]; then
  DBVER=$word
  fi
done

if id -u "$NEMUSER" >/dev/null 2>&1; then
  echo -e "\033[32m*\033[m User exists. Aborting because might break something."
  exit
else
  echo -e "\033[32m*\033[m Creating user $NEMUSER"
  adduser $NEMUSER -s /sbin/nologin -d /opt/$NEMUSER
fi

if [ ! -e "nis-$NISVER.tgz" ]; then
  echo -e "\033[32m*\033[m Downloading NIS and signature files"
  curl -# -O https://bob.nem.ninja/nis-$NISVER.tgz 
  curl -# -O https://bob.nem.ninja/nis-$NISVER.tgz.sig 
else
  echo -e "\033[32m*\033[m Nis already downloaded."
fi

if [ ! -e "$DBVER" ]; then
  echo -e "\033[32m*\033[m Downloading bootstrap and signature files"
  curl -# -O https://bob.nem.ninja/$DBVER
  curl -# -O https://bob.nem.ninja/$DBVER.sig
else
  echo -e "\033[32m*\033[m Initial blockchain $DBVER already downloaded."
fi

# Create NEM application content
if [ ! -e "/opt/$NEMUSER" ]; then
  echo -e "\033[32m*\033[m Creating NIS specific directories"
  mkdir -p /opt/$NEMUSER/nem/nis/data
  mkdir -p /opt/$NEMUSER/nem/nis/logs/oldlogs
else
  echo -e "\033[32m*\033[m Required directory exist. Aborting because might break something."
  exit
fi

# Add initial NEM blockhain in place
if [ ! -e "/opt/$NEMUSER/nem/nis/data/nis5_mainnet.h2.db" ]; then
  unzip $DBVER -d /opt/$NEMUSER/nem/nis/data
else 
  echo -e "\033[32m*\033[m Blockchain found."
fi

# Install NEM package
echo -e "\033[32m*\033[m Installing NIS to directory /opt/$NEMUSER"
tar xzf nis-$NISVER.tgz -C /opt/$NEMUSER
mkdir /opt/$NEMUSER/nis_$NISVER
ln -s /opt/$NEMUSER/nis_$NISVER /opt/$NEMUSER/nis_latest
mv /opt/$NEMUSER/package/* /opt/$NEMUSER/nis_latest
rm -rf /opt/$NEMUSER/package/
cp /opt/$NEMUSER/nis_latest/nis/config.properties /opt/$NEMUSER/nem/config-user.properties

#
# Create systemd service 
#
if [ -e "/etc/systemd/system/nis.service" ]; then
  echo -e "\033[32m*\033[m Systemd service file already exists. Aborting because might break something."
  exit
fi

echo -e "\033[32m*\033[m Creating systemd service"
cat > /etc/systemd/system/nis.service <<EOF
[Unit]
Description=NEM Infrastructure Server
After=network.target

[Service]
Type=simple
User=$NEMUSER
WorkingDirectory=/opt/$NEMUSER/nis_latest/nis
ExecStart=/usr/bin/java -Xms512M -Xmx1G -cp "/opt/$NEMUSER/nem:.:./*:../libs/*" org.nem.deploy.CommonStarter
ExecStop=/usr/bin/curl http://localhost:7890/shutdown
SuccessExitStatus=143
TimeoutStopSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#
# Install crontab script to compress old log files daily
#
if [ -e "/etc/cron.daily/nemnis_logcompress.sh" ]; then
  echo -e "\033[32m*\033[m Cron daily file already exists. Aborting because might break something."
  exit
fi

echo -e "\033[32m*\033[m Installing logrotate and compress script to cron daily"
cat > /etc/cron.daily/nemnis_logcompress.sh <<EOF
#!/bin/bash

NEMUSER=$NEMUSER

if [ ! -d /opt/\$NEMUSER/nem/nis/logs/oldlogs ]; then
  mkdir /opt/\$NEMUSER/nem/nis/logs/oldlogs
fi

stamp=\$(date +%Y%m%d-%H%M%S)
find /opt/\$NEMUSER/nem/nis/logs/*.log -maxdepth 1 -printf "%f\n" -type f | \
while read -r x
do
  if [ $x != "nis-0.log" ]; then
    gzip -c -9 "/opt/\$NEMUSER/nem/nis/logs/$x" > "/opt/\$NEMUSER/nem/nis/logs/oldlogs/\$x-\$stamp.gz"
    rm -rf "/opt/\$NEMUSER/nem/nis/logs/\$x"
  fi
done
EOF

chmod 555 /etc/cron.daily/nemnis_logcompress.sh
chown -R $NEMUSER:$NEMUSER /opt/$NEMUSER

#
# Add NEM Nis service to firewalld
#
if [ -e "/etc/firewalld/services/nem-nis.xml" ]; then
  echo -e "\033[32m*\033[m Cron daily file already exists. Aborting because might break something."
  exit
fi

echo -e "\033[32m*\033[m Adding NIS as firewall service and allowing port 7890 to server"
cat > /etc/firewalld/services/nem-nis.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service version="1.0">
  <short>nem-nis</short>
  <description>NEM Network Infrastructure Server</description>
  <port port="7890" protocol="tcp" />
</service>
EOF

echo -e "\033[32m*\033[m Reloading firewall service"
firewall-cmd --reload
firewall-cmd --permanent --zone=public --add-service=nem-nis
systemctl restart firewalld.service

echo -e "\033[31m**\033[m PLEASE MODIFY CONFIGURATION FILE /opt/$NEMUSER/nem/config-user.properties"

echo -e "\033[31m**\033[m After you have modified /opt/$NEMUSER/nem/config-user.properties"
echo -e "\033[31m**\033[m you can start NEM Nis with command \"\033[32msystemctl start nis\033[m\""
echo -e "\033[31m**\033[m"
echo -e "\033[31m**\033[m To stop NIS from shell: \"\033[32msystemctl stop nis\033[m\""

