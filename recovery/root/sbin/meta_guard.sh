#!/sbin/sh
# meta_guard.sh - FDE metadata partition backup/restore guard (TB8505F)
#
# The device uses FDE with forceencrypt=/dev/block/.../by-name/metadata:
# the crypto master-key blob and crypto params live on the *metadata*
# partition.  vold's decrypt path (checkpw/mount) can rewrite that
# partition, and a metadata partition left in a half-updated state makes
# the OS unable to decrypt /data on the next boot.
#
# Strategy:
#   backup  - run at every recovery boot (init.recovery.crypto.rc, `on fs`,
#             i.e. BEFORE any vold decrypt attempt).  Captures the pristine
#             metadata state the OS last left behind.  Kept in /tmp (RAM)
#             for the duration of the session, and persisted to /data when
#             /data is mounted (post-decrypt), as a fallback for later
#             sessions.
#   restore - run by the TWRP reboot hook (patches/0012, via
#             /system/bin/rebootmeta.sh) right before ANY state transition
#             (reboot system / recovery / bootloader / poweroff / ...).
#             Writes the boot-time backup back onto the metadata partition,
#             undoing whatever vold decrypt did during this session.
#
# Logs go to /dev/kmsg (survives into pmsg-ramoops, same channel as vold)
# and /tmp/meta_guard.log for on-device debugging.

META_DEV=/dev/block/platform/bootdevice/by-name/metadata
TMP_BAK=/tmp/meta_backup.img
DATA_BAK=/data/local/tmp/meta_backup.img
KMSG=/dev/kmsg
LOG=/tmp/meta_guard.log

log() {
    echo "[meta_guard] $*" > "$KMSG" 2>/dev/null
    echo "[meta_guard] $*" >> "$LOG" 2>/dev/null
}

data_mounted() {
    grep -q ' /data ' /proc/mounts 2>/dev/null
}

# Write a pristine copy of the current backup into /data (only useful once
# /data is decrypted and mounted; /data/local/tmp survives TWRP sessions).
persist_copy() {
    local src="$1"
    [ -f "$src" ] || return 1
    data_mounted || return 1
    mkdir -p /data/local/tmp 2>/dev/null || return 1
    cp -f "$src" "$DATA_BAK" 2>/dev/null && log "persisted copy -> $DATA_BAK"
}

backup() {
    if [ ! -b "$META_DEV" ]; then
        log "backup: metadata device $META_DEV not found, skipping"
        exit 0
    fi

    # Blank/corrupt guard: if the first 1MB of the metadata partition is
    # all zeros the partition is empty/wiped (failed flash, wipe, or vold
    # damage before we could snapshot it). A backup taken from it would be
    # garbage and must NEVER overwrite the persisted good copy in
    # $DATA_BAK from an earlier session. Skip the whole backup so restore
    # falls back to that preserved copy instead.
    # (Compare against /dev/zero: grep '[^0]' does NOT work here, every
    # NUL byte also matches '[^0]'.)
    if dd if="$META_DEV" bs=4096 count=256 2>/dev/null | cmp -s - /dev/zero; then
        log "backup: $META_DEV first 1MB is all zeros (blank/corrupt), keeping old $DATA_BAK"
        exit 0
    fi

    # Read via a temp file so a failed/partial read never clobbers a
    # previous good backup (e.g. /data fallback from an earlier session).
    dd if="$META_DEV" of="$TMP_BAK.tmp" bs=4096 2>/dev/null
    if [ ! -f "$TMP_BAK.tmp" ] || [ ! -s "$TMP_BAK.tmp" ]; then
        log "backup: dd produced empty/missing image, keeping old backup"
        rm -f "$TMP_BAK.tmp"
        exit 1
    fi
    mv -f "$TMP_BAK.tmp" "$TMP_BAK"
    local sz
    sz=$(stat -c %s "$TMP_BAK" 2>/dev/null)
    log "backup: metadata ($sz bytes) -> $TMP_BAK"

    # Opportunistically persist for the next session (only when /data is
    # already mounted, which normally happens after decrypt).
    persist_copy "$TMP_BAK"
}

restore() {
    local src=""
    if [ -f "$TMP_BAK" ]; then
        src="$TMP_BAK"
    elif data_mounted && [ -f "$DATA_BAK" ]; then
        src="$DATA_BAK"
        log "restore: /tmp backup missing, using persisted $DATA_BAK"
    fi

    if [ -z "$src" ]; then
        log "restore: no backup found, skipping (nothing to undo)"
        exit 0
    fi
    if [ ! -b "$META_DEV" ]; then
        log "restore: metadata device $META_DEV not found, skipping"
        exit 1
    fi

    local sz
    sz=$(stat -c %s "$src" 2>/dev/null)
    log "restore: writing $sz bytes from $src -> $META_DEV"
    dd if="$src" of="$META_DEV" bs=4096 2>/dev/null
    sync
    log "restore: done"

    # Keep the persisted copy in sync with the restored (pristine) image.
    persist_copy "$src"
}

case "$1" in
    backup)  backup ;;
    restore) restore ;;
    *)
        echo "usage: meta_guard.sh {backup|restore}" >&2
        exit 2
        ;;
esac

exit 0
