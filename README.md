### TWRP for Lenovo Tab M8 Wi-Fi TB-8505F

This tree is made from Android 10 and builds with the twrp-10.0-deprecated manifest (TWRP 10.0, TeamWin android-10.0 recovery).

### Working
- Micro SD Card
- USB OTG
- Brightness
- ADB
- FDE decryption (aes-cbc-essiv:sha256) via system vold + keymaster/gatekeeper HALs + vdc_pie

### Decryption
- **No lockscreen set**: /data is auto-decrypted at boot using the default password (`default_password`, see `recovery/root/sbin/auto_decrypt.sh`).
- **Lockscreen set**: enter the password on TWRP's decrypt page, or run:
  `adb shell twrp decrypt <your-password>`

### Build
GitHub Actions workflow (`.github/workflows/build.yml`) builds `recovery.img` and uploads it as an artifact.
Manual build:
```
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-10.0-deprecated
repo sync -c -j$(nproc) --force-sync
cp -r device/Lenovo/TB8505F $ANDROID_ROOT/device/Lenovo/TB8505F
cd $ANDROID_ROOT && bash device/Lenovo/TB8505F/patches/apply.sh
source build/envsetup.sh && lunch omni_TB8505F-eng && mka recoveryimage
```

### Notes on the source patches (`patches/`)
The twrp-10.0-deprecated manifest pins an old TWRP 10.0 recovery tree that has
several build/runtime issues when `TW_CRYPTO_USE_SYSTEM_VOLD` is enabled. The
patches fix:
1. `vold_decrypt.cpp`: unused-function errors for the service management helpers when `TW_CRYPTO_SYSTEM_VOLD_SERVICES` is not defined.
2. `vold_decrypt.cpp`: `LOGINFO` macro redefinition conflict with `twcommon.h`.
3. `vold_decrypt/Android.mk`: missing include paths for `tw_atomic.hpp` (from `twrpinstall/include`) and ziparchive/android-base headers.
4. `prebuilt/Android.mk`: gate the prebuilt `vdc_pie` to SDK < 28 to avoid a duplicate module definition with the source-built one.
5. `etc/init.rc`: import `/init.recovery.crypto.rc` so the auto-decrypt service actually runs.
