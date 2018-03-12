# NemToolsLinux
Tools that help working with NEM blockchain. **Scripts are FAN made, check scripts yourself before you use them! I cannot help you if you break production server with these scripts.**

**NEM Devs have not checked or supported these scripts, use at your own risk!**

# checkIntegrityAgainstApostille.sh
Will check file integrity against NEM blockchain Apostille service. User must download file and signature file before applying this script. When applying this script, it only needs filename (it assumes that signature file is same name but with suffix ".sig").

Supported hashes: MD5, SHA1, SHA256 and SHA3
Supported distributions: Centos 7, Ubuntu 1604 (and above? have not tested)

(Note: Should be safe script to use, does not do any changes to system.)

# install_nemnis.sh

**Warning:** This script must be ran as root and can break your server! **Check script before running it! And/or test it on testserver before using it.**

Install script for NEM Nis on Centos 7 and Ubuntu 1604. Features:

Details:
* Creates user "nemnis" (system account, no login, no password)
* Creates systemd service "nemnis"
* Downloads latest NIS and bootstrap file
* Uses /opt/nemnis as home directory, creates symlink nis_latest and is referred in systemctl conf file
* NIS configuration (config-user.properties) in /opt/nemnis/nem directory => no need to update/replace/reconfigure configuration when NIS is updated
* Places simple logrotate script to cron daily
* Creates configuration file for Centos firewall (allows port 7890 in) OR allows tcp port 7890 in on Ubuntu
