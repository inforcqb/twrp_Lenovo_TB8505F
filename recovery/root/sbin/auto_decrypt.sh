#!/sbin/sh
# Auto-decrypt /data using vold after boot
# FDE: aes-cbc-essiv:sha256 with default_password
sleep 8
/sbin/twrp decrypt default_password
