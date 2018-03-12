#!/bin/bash
#
# Description: Install script to install NEM Infrastuctrure Server on Centos 7. Will also bootstrap, 
#              set log cleaning and add possibility to control NIS using Centos/Ubuntu systemtools (systemctl)
# Details:
# * Creates user "nemnis" (system account, no login, no password)
# * Creates service "nemnis" for OS (control with systemctl command)
# * Downloads latest NIS and bootstrap file
# * Uses /opt/nemnis as home directory, creates symlink nis_latest and is referred in systemctl conf file
# * NIS configuration (config-user.properties) in /opt/nemnis/nem directory => no need to update/replace/reconfigure 
#   configuration when NIS is updated (though, you need to check for possible new params)
# * Places simple logrotate script to cron daily
# * Creates configuration file for Centos firewall (allows port 7890 in) OR allows port 7890 in on Ubuntu (ufw)

# NIS upgrade (example number only!, also "nemnis" might be different if you changed user from script):
# tar xzf nis-0.7.70.tgz -C /opt/nemnis
# mkdir /opt/nemnis/nis-0.7.70
# mv /opt/nemnis/package/* /opt/nemnis/nis-0.7.70
# rm -rf /opt/nemnis/nis_latest
# ln -s /opt/nemnis/nis-0.7.70 /opt/nemnis/nis_latest

# After above, run "systemctl stop nemnis" and "systemctl start nemnis"

# START: Variables that can be changed, please know what you are doing.
NEMUSER=nemnis # User and group that will be created and used for NEM Nis
NISVER=""      # Nis version will be autodetected, fill this only if you want to install certain version. Please note that it might not be available.
# END: Variables that can be changed.

if [ "$EUID" -ne 0 ]
  then echo -e "\033[31mPlease run as root\033[m"
  exit
fi

OSVER=""
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OSVER="$NAME $VERSION_ID"
fi

if [ "$OSVER" != "Ubuntu 16.04" ]; then
  if [ "$OSVER" != "CentOS Linux 7" ]; then
    echo -e "\033[31mInstallation script has not been tested on this Linux distribution ($OSVER).\033[m"
    while true; do
      read -p "Do you really want to continue (y/n)?" choice
      case "$choice" in
        [Yy]* ) echo "Uh, continuing installation"; break;;
        [Nn]* ) echo "Quitting"; exit;;
        * ) echo "Please answer y or n (yes or no)"
      esac
   done
  fi
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
    echo -e "\033[32m*\033[m Following programs missing:\033[31m$MISSINGPROGS\033[m"
    echo -e "\033[31m* Aborting...\033[m"
    exit
fi

# START: Make tests first and abort if something is not right
ALLGOOD=1
echo -e "\033[32m**\033[m Running tests before executing script..."
if [ -d /opt/$NEMUSER ]; then
  echo -e "\033[32m*\033[m Directory /opt/$NEMUSER already exist. Please modify script."
  ALLGOOD=0
fi
if id -u "$NEMUSER" >/dev/null 2>&1; then
  echo -e "\033[32m*\033[m User exists. Please modify script."
  ALLGOOD=0
fi
if [ -e "/etc/systemd/system/nemnis.service" ]; then
  echo -e "\033[32m*\033[m Systemd service file already exists."
  ALLGOOD=0
fi
if [ -e "/etc/cron.daily/nemnis_logcompress.sh" ]; then
  echo -e "\033[32m*\033[m Cron daily file already exists. Please sort it out."
  ALLGOOD=0
fi

if [ $ALLGOOD -eq 0 ]; then
  echo -e "\033[31m* Duh, bumped into troubles, please sort them out before executing this script again. Aborting.\033[m"
  exit
fi
# END: tests

# START: Actual installation
if [ -z $NISVER ]; then
  echo -e "\033[32m*\033[m Checking latest NIS version and getting latest bootstrap file"
  NISVER=$(curl -s http://bob.nem.ninja/version.txt)
  if [ -z $NISVER ]; then
    echo -e "\033[31m* Oh snap! Could not find any version of Nis. Aborting.\033[m"
    exit
  else
    echo -e "\033[32m*\033[m Found version $NISVER"
  fi
else 
  echo -e "\033[32m*\033[m Trying to download Nis version $NISVER (user specified) and getting latest bootstrap file"
fi
DBVER=""
# Selecting "latest" DBVER assumes stupidly that curl will list latest DB last. This might not always be the case.
# TODO: Check latest DBVER using timestamps.
htmltext=$(curl -s "http://bob.nem.ninja" --list-only | sed -e 's/<[^>]*>/ /g' | grep db.zip | grep -v db.zip.sig)
set -- junk $htmltext
shift
for word; do
if [[ $word = *"db.zip"* ]]; then
  DBVER=$word
  fi
done

if [ ! -e "nis-$NISVER.tgz" ]; then
  echo -e "\033[32m*\033[m Downloading NIS and signature files"
  curl -# -O --show-error --fail https://bob.nem.ninja/nis-$NISVER.tgz 
  if [ $? -ne 0 ]; then
    echo -e "\033[31m* Failed to download OR detect Nis. Abort!\033[m"
    exit
  fi
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

echo -e "\033[32m*\033[m Creating user $NEMUSER"
if [ "$OSVER" == "Ubuntu 16.04" ]; then
  addgroup --system $NEMUSER
  adduser --system --no-create-home --home /opt/$NEMUSER --disabled-password --disabled-login --ingroup $NEMUSER $NEMUSER
elif [ "$OSVER" == "CentOS Linux 7" ]; then
  adduser $NEMUSER -s /sbin/nologin -d /opt/$NEMUSER
fi
# Create NEM application content
echo -e "\033[32m*\033[m Creating NIS specific directories"
mkdir -p /opt/$NEMUSER/nem/nis/data
mkdir -p /opt/$NEMUSER/nem/nis/logs/oldlogs

# Add initial NEM blockhain in place
if [ ! -e "/opt/$NEMUSER/nem/nis/data/nis5_mainnet.h2.db" ]; then
  if [ ! -e "$DBVER" ]; then
    echo -e "\033[31m* Bootstrap was not downloaded, will continue installation still.\033[m"
  else 
    unzip $DBVER -d /opt/$NEMUSER/nem/nis/data
  fi
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

echo -e "\033[32m*\033[m Creating systemd service"
cat > /etc/systemd/system/nemnis.service <<EOF
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
echo -e "\033[32m*\033[m Allowing port 7890(tcp) in firewall."
if [ "$OSVER" == "Ubuntu 16.04" ]; then
  ufw allow 7890/tcp
elif [ "$OSVER" == "CentOS Linux 7" ]; then
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
fi

echo -e "\033[31m**\033[m PLEASE MODIFY CONFIGURATION FILE /opt/$NEMUSER/nem/config-user.properties"

echo -e "\033[31m**\033[m After you have modified /opt/$NEMUSER/nem/config-user.properties"
echo -e "\033[31m**\033[m you can start NEM Nis with command \"\033[32msystemctl start nemnis\033[m\""
echo -e "\033[31m**\033[m"
echo -e "\033[31m**\033[m To stop NIS from shell: \"\033[32msystemctl stop nemnis\033[m\""

