#!/sbin/sh
# Auto-decrypt /data using vold after TWRP has started.
# FDE: aes-cbc-essiv:sha256 with default_password (no lockscreen set).
# The 'twrp decrypt' command is sent to the main TWRP process via the ORS
# interface, so it blocks until TWRP is ready to accept commands.
KMSG=/dev/kmsg
log() { echo "[auto_decrypt] $*" > $KMSG; }

log "starting auto-decrypt with default_password"
sleep 8
/sbin/twrp decrypt default_password
log "auto-decrypt command finished"
