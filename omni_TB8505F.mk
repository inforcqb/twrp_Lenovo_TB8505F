#
# Copyright (C) 2021 The Android Open Source Project
# Copyright (C) 2021 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Inherit from our custom product configuration
$(call inherit-product, vendor/omni/config/common.mk)

# Device identifier. This must come after all inclusions
PRODUCT_DEVICE := TB8505F
PRODUCT_NAME := omni_TB8505F
PRODUCT_BRAND := Lenovo
PRODUCT_MODEL := Lenovo TB-8505F
PRODUCT_MANUFACTURER := LENOVO

PRODUCT_SHIPPING_API_LEVEL := 28

# Crypto / FDE packages for decryption
PRODUCT_PACKAGES += \
    libkeymaster4 \
    libkeymaster4support \
    libkeymaster_messages \
    libkeymaster_portable \
    libpuresoftkeymasterdevice \
    libsoftgatekeeper \
    android.hardware.keymaster@4.0 \
    android.hardware.keymaster@3.0 \
    android.hardware.gatekeeper@1.0 \
    libkeystore-engine-wifi-hidl \
    libkeystore-wifi-hidl \
    libkmsetkey \
    keystore \
    gatekeeperd

# MTK keymaster attestation
PRODUCT_PACKAGES += \
    vendor.mediatek.hardware.keymaster_attestation@1.0 \
    vendor.mediatek.hardware.keymaster_attestation@1.1

# Vold and related
PRODUCT_PACKAGES += \
    vold \
    secdiscard
