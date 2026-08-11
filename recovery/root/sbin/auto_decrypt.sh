#!/sbin/sh
# Auto-decrypt /data using vold after TWRP has started.
# FDE: aes-cbc-essiv:sha256 with default_password (no lockscreen set).
# 'twrp decrypt' is the ORS client (/system/bin/twrp) that talks to the
# main TWRP process; retry until the ORS interface is ready.
KMSG=/dev/kmsg
log() { echo "[auto_decrypt] $*" > $KMSG; }

log "starting auto-decrypt with default_password"
for i in 1 2 3 4 5 6 7 8 9 10; do
    if /system/bin/twrp decrypt default_password; then
        log "auto-decrypt succeeded (attempt $i)"
        exit 0
    fi
    log "auto-decrypt attempt $i failed, retrying in 5s"
    sleep 5
done
log "auto-decrypt gave up after 10 attempts"
