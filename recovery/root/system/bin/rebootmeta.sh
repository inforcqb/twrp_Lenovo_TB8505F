#!/sbin/sh
# Reboot hook installed by patches/0012: TWRP runs this script (if present)
# right before ANY reboot/poweroff transition.  Restore the FDE metadata
# partition backup taken at boot, undoing any damage vold decrypt may have
# done to it during this session.
/sbin/sh /sbin/meta_guard.sh restore
exit 0
