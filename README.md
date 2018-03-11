# NemToolsLinux
Tools that help working with NEM blockchain

# checkIntegrityAgainstApostille.sh
Will check file integrity against NEM blockchain Apostille service. User must download file and signature file before applying this script. When applying this script, it only needs filename (it assumes that signature file is same name but with suffix ".sig").

Supported hashes: MD5, SHA1, SHA256 and SHA3
Supported distributions: Centos 7, Ubuntu 1604 (and above? have not tested)

# install_nis_on_centos7.sh
Install script for NEM Nis on Centos 7. Features:

Details:
* Creates user "nemnis" (system account, no login, no password)
* Downloads latest NIS and bootstrap file
* Uses /opt/nemnis as home directory, creates symlink nis_latest and is referred in systemctl conf file
* NIS configuration (config-user.properties) in /opt/nemnis/nem directory => no need to update/replace/reconfigure configuration when NIS is updated
* Places simple logrotate script to cron daily
* Creates configuration file for Centos firewall (allows port 7890 in)
