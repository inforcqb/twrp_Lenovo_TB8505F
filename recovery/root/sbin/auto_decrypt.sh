#!/sbin/sh
# Auto-decrypt /data using vold after TWRP has started.
# FDE: aes-cbc-essiv:sha256. If a lock screen (pattern/pin/password) is set,
# default_password will never match - we try it once (covers no-lockscreen
# devices), then stop. Retrying in a loop is pointless and worse: each failed
# attempt can leave a stale dm-crypt device (dm-0) behind, which then makes
# the real GUI decrypt fail with "Cannot create dm-crypt device ... busy".
KMSG=/dev/kmsg
log() { echo "[auto_decrypt] $*" > $KMSG; }

# Enable the debug mount/device monitor (see dm_monitor.sh in crypto.rc)
# so every mount change and dm-* creation during decryption is logged.
setprop dm_monitor.enabled 1

# Only attempt when the device reports encryption.
STATE=$(getprop ro.crypto.state)
if [ "$STATE" != "encrypted" ]; then
    log "not encrypted (ro.crypto.state=$STATE), nothing to do"
    exit 0
fi

# Clean up any stale dm-crypt devices from a previous failed attempt.
# vold leaves dm-0 (name "userdata") behind when checkpw fails after the
# master key was decrypted; a leftover dm-0 makes every later attempt fail
# with "Cannot create dm-crypt device userdata: Device or resource busy".
for dm in /dev/block/dm-*; do
    [ -e "$dm" ] || continue
    name=$(cat /sys/block/$(basename $dm)/dm/name 2>/dev/null)
    if [ "$name" = "userdata" ]; then
        log "removing stale dm device $dm (userdata)"
        # DM_DEV_REMOVE via dmsetup if present, else fall back to ioctl helper
        if command -v dmsetup >/dev/null 2>&1; then
            dmsetup remove "$name" 2>/dev/null && log "dmsetup removed $name"
        fi
        # Some recoveries carry a tiny dm_remove helper; use it if available.
        if [ -x /sbin/dm_remove ]; then
            /sbin/dm_remove "$name" 2>/dev/null && log "dm_remove removed $name"
        fi
    fi
done

log "device encrypted, trying default_password once"
if /system/bin/twrp decrypt default_password; then
    log "auto-decrypt succeeded with default_password"
    exit 0
fi
log "default_password failed (a lock screen is probably set); leaving decrypt to GUI"
exit 1
