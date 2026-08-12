#!/sbin/sh
# Debug monitor for FDE decryption: logs every mount change, /dev/block
# device creation (dm-*) and vold/keymaster kernel log lines with timestamps.
# Writes to /tmp/dm_monitor.log (and kmsg for visibility).
LOG=/tmp/dm_monitor.log
KMSG=/dev/kmsg
ts() { date +%H:%M:%S.%N; }
log() { echo "[$(ts)] $*" >> $LOG; echo "[dm_monitor] $*" > $KMSG 2>/dev/null; }

log "=== dm_monitor start ==="
log "--- initial /dev/block/dm-* ---"
ls -la /dev/block/dm-* >> $LOG 2>&1
log "--- initial mounts (dm/userdata/data) ---"
grep -E 'dm-|userdata| /data' /proc/mounts >> $LOG 2>&1
log "--- initial props ---"
log "crypto.state=$(getprop ro.crypto.state) type=$(getprop ro.crypto.type)"
log "hwsm.ready=$(getprop hwservicemanager.ready)"

# 1) inotify watch on /dev/block (device create/remove)
inotifyd - /dev/block:ec 2>>$LOG &
INOPID=$!
log "inotifyd pid=$INOPID watching /dev/block"

# 2) poll /proc/mounts every second for changes
LAST_MNT=""
( while true; do
    MNT=$(grep -E 'dm-|userdata| /data| /system_root| /vendor' /proc/mounts 2>/dev/null)
    if [ "$MNT" != "$LAST_MNT" ]; then
        log "MOUNT-CHANGE:"
        echo "$MNT" | while IFS= read -r l; do log "  $l"; done
        LAST_MNT="$MNT"
    fi
    DMS=$(ls /dev/block/dm-* 2>/dev/null | tr '\n' ' ')
    if [ "$DMS" != "$LAST_DMS" ]; then
        log "DM-CHANGE: [$DMS]"
        LAST_DMS="$DMS"
    fi
    sleep 1
  done ) &
POLLPID=$!
log "poll pid=$POLLPID"

# 3) background dmesg tail for vold/keymaster/cryptfs
( while true; do
    dmesg 2>/dev/null | grep -iE 'vold|Cryptfs|keymaster|dm-0|dm-crypt' | tail -3 >> $LOG
    sleep 2
  done ) &
DMESGPID=$!
log "dmesg pid=$DMESGPID"

log "=== dm_monitor ready (pids: $INOPID $POLLPID $DMESGPID) ==="
echo ready > /tmp/dm_monitor.ready
# keep alive
while true; do sleep 60; done
