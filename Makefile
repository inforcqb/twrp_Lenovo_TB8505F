# Makefile for TWRP TB8505F (FDE decryption build)
#
# Wraps the twrp-10.0-deprecated manifest build into simple targets.
# The device tree lives in device/Lenovo/TB8505F inside an Android source
# tree; this Makefile can be used either from the device tree directory
# (with ANDROID_ROOT set) or from the Android root.
#
# Usage (from the Android source root, or set ANDROID_ROOT):
#   make -f device/Lenovo/TB8505F/Makefile setup   # repo init
#   make -f device/Lenovo/TB8505F/Makefile sync    # repo sync
#   make -f device/Lenovo/TB8505F/Makefile build   # apply patches + build recovery.img
#   make -f device/Lenovo/TB8505F/Makefile flash   # fastboot flash recovery
#
# Variables:
#   ANDROID_ROOT   - Android source root (default: current dir if it has build/envsetup.sh)
#   DEVICE_PATH    - device tree path (default: $$ANDROID_ROOT/device/Lenovo/TB8505F)
#   JOBS           - parallel jobs (default: nproc)
#   OUT            - output recovery.img path (default: out/target/product/TB8505F/recovery.img)

ANDROID_ROOT ?= $(shell pwd)
DEVICE_PATH  ?= $(ANDROID_ROOT)/device/Lenovo/TB8505F
JOBS         ?= $(shell nproc 2>/dev/null || echo 4)
OUT          ?= $(ANDROID_ROOT)/out/target/product/TB8505F/recovery.img
MANIFEST     ?= https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git
MANIFEST_BRANCH ?= twrp-10.0-deprecated

.PHONY: help setup sync apply build flash clean dmtool

help:
	@echo "TWRP TB8505F build targets:"
	@echo "  make setup   - repo init (twrp-10.0-deprecated manifest)"
	@echo "  make sync    - repo sync sources"
	@echo "  make apply   - apply device tree + source patches"
	@echo "  make build   - apply + build recovery.img (uses ccache if available)"
	@echo "  make flash   - fastboot flash recovery (device must be in fastboot)"
	@echo "  make dmtool  - build the static dm_remove helper (needs gcc-aarch64-linux-gnu)"
	@echo "  make clean   - rm -rf out/target/product/TB8505F"
	@echo
	@echo "Variables: ANDROID_ROOT=$(ANDROID_ROOT) DEVICE_PATH=$(DEVICE_PATH) JOBS=$(JOBS)"

setup:
	@test -n "$(ANDROID_ROOT)" || (echo "set ANDROID_ROOT" && exit 1)
	cd $(ANDROID_ROOT) && repo init --depth=1 -u $(MANIFEST) -b $(MANIFEST_BRANCH)

sync:
	cd $(ANDROID_ROOT) && repo sync -c -j$(JOBS) --force-sync

apply:
	@mkdir -p $(ANDROID_ROOT)/device/Lenovo
	@if [ ! -d $(DEVICE_PATH) ]; then \
		echo "device tree not found at $(DEVICE_PATH), copying from $(CURDIR)"; \
		rsync -a --exclude='.git' --exclude='.github' --exclude='extracted*' \
			--exclude='*.py' --exclude='*.md' $(CURDIR)/ $(DEVICE_PATH)/; \
	fi
	cd $(ANDROID_ROOT) && bash $(DEVICE_PATH)/patches/apply.sh

build: apply
	cd $(ANDROID_ROOT) && \
		export USE_CCACHE=1 ALLOW_MISSING_DEPENDENCIES=true && \
		source build/envsetup.sh && lunch omni_TB8505F-eng && \
		mka recoveryimage -j$(JOBS)
	@test -f $(OUT) && echo "OK: $(OUT)" || (echo "build failed: $(OUT) missing" && exit 1)

flash:
	fastboot flash recovery $(OUT)
	fastboot reboot recovery

# Static helper that removes a stale dm-crypt device (see tools/dm_remove.c).
# Needs the aarch64 cross compiler; the binary goes into the recovery ramdisk
# automatically when built via the repo tree (build target).
dmtool:
	@command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || \
		(echo "install gcc-aarch64-linux-gnu first (apt install gcc-aarch64-linux-gnu)" && exit 1)
	mkdir -p $(DEVICE_PATH)/recovery/root/sbin
	aarch64-linux-gnu-gcc -static -O2 -o $(DEVICE_PATH)/recovery/root/sbin/dm_remove $(DEVICE_PATH)/tools/dm_remove.c
	file $(DEVICE_PATH)/recovery/root/sbin/dm_remove

clean:
	rm -rf $(ANDROID_ROOT)/out/target/product/TB8505F
