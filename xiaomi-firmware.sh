#!/bin/bash
# Copyright (C) 2023 Giovanni Ricca
# SPDX-License-Identifier: GPL-3.0-or-later

# Logging defs
LOGI() {
    echo -e "\033[32m[INFO] xiaomi-firmware: $1\033[0m"
}

LOGW() {
    echo -e "\033[33m[WARNING] xiaomi-firmware: $1\033[0m"
}

LOGE() {
    echo -e "\033[31m[ERROR] xiaomi-firmware: $1\033[0m"
}

# Vars
MY_DIR="${PWD}"
BIN_PATH="${MY_DIR}"/bin/linux-$(uname -m)
ANDROID_ROOT="${MY_DIR}"/..
VENDOR_FIRMWARE="${ANDROID_ROOT}"/vendor/firmware
INCLUDE_DTBO="false"
RECOVERY_PACKAGE=""
DEVICE=""

while [ "$#" -gt 0 ]; do
    case "${1}" in
        --dtbo)
            INCLUDE_DTBO="true"
            ;;
        -d | --device)
            DEVICE="${2}"
            ;;
        --zip)
            RECOVERY_PACKAGE="${MY_DIR}"/"${2}"
            ;;
    esac
    shift
done

if [[ -z "$RECOVERY_PACKAGE" || -z "${DEVICE}" ]]; then
    LOGE "Please define the required values \"--device\" and \"--zip\""
    exit 0
fi

blocklist=(
    ## General ##
    "boot"
    "odm"
    "logo"
    "product"
    "recovery"
    "system"
    "vbmeta"
    "vendor"
    ## General (MTK) ##
    "preloader"
    ## Oplus ##
    "my_"
    ## Xiaomi ##
    "mi_ext"
)

if [ "$INCLUDE_DTBO" == "false" ]; then
    blocklist+=("dtbo")
fi

# Defs
extract_fwab() {
    # Extract the payload
    "${BIN_PATH}"/android-ota-extractor "${RECOVERY_PACKAGE}"
    # Remove the payload.bin file
    rm -rf payload.bin
}

extract_fwaonly() {
    # Extract firmware-update folder
    unzip "${RECOVERY_PACKAGE}" "firmware-update/*"
    # Go inside extracted dir
    cd firmware-update
}

clean_out() {
    # Cleanup out dir
    cd "${MY_DIR}"
    rm -rf out
    mkdir -p out/
}

## START OF THE MAGIC ##

# Check if the device is AB or A-Only
if zipinfo -1 "${RECOVERY_PACKAGE}" | grep -q payload.bin; then
    LOGI "Detected payload.bin, applying A/B edits"
    IS_AB=true
fi

# Generate dummy device makefile
rm -rf "${VENDOR_FIRMWARE}"/"${DEVICE}"
mkdir -p "${VENDOR_FIRMWARE}"/"${DEVICE}"/radio
touch "${VENDOR_FIRMWARE}"/"${DEVICE}"/firmware.mk
if [ "${IS_AB}" = true ]; then
    touch "${VENDOR_FIRMWARE}"/"${DEVICE}"/config.mk
fi

# Copy out device firmware
clean_out
cd out/

# Check if the device is AB or A-Only
if [ "${IS_AB}" = true ]; then
    # Extract for AB roms
    LOGI "Extracting payload.bin from ${RECOVERY_PACKAGE}"
    LOGW "This operation will take a while, take a seat and wait :D"
    extract_fwab &>/dev/null
    result=$?
else
    # Extract for A-Only roms
    LOGI "Extracting firmware-update/ folder from ${RECOVERY_PACKAGE}"
    extract_fwaonly &>/dev/null
    result=$?
fi

case ${result} in
    0)
        LOGI "Extracted successfully!"
        ;;
    *)
        LOGE "Extraction!"
        exit 0
        ;;
esac

LOGI "Cleaning up the out dir from useless files"
for image in ${blocklist[@]}; do
    rm -rf *"${image}"*
done

# Push on vendor/firmware
LOGI "Copying the firmware files inside ${ANDROID_ROOT}/vendor/firmware/${DEVICE}/radio"
mv * "${ANDROID_ROOT}"/vendor/firmware/"${DEVICE}"/radio
chmod 644 "${ANDROID_ROOT}"/vendor/firmware/"${DEVICE}"/radio/*

# Generate device makefile
LOGI "Generating ${VENDOR_FIRMWARE}/${DEVICE}/firmware.mk"
cat <<EOF >"${VENDOR_FIRMWARE}"/"${DEVICE}"/firmware.mk
LOCAL_PATH := \$(call my-dir)

ifeq (\$(TARGET_DEVICE),${DEVICE})

RADIO_FILES := \$(wildcard \$(LOCAL_PATH)/radio/*)
\$(foreach f, \$(notdir \$(RADIO_FILES)), \\
    \$(call add-radio-file,radio/\$(f)))

endif
EOF

if [ "${IS_AB}" = true ]; then
    for firmware_file in $(ls -1 "${VENDOR_FIRMWARE}"/"${DEVICE}"/radio); do
        if [ ! -z ${LAST_FILE} ]; then
            partitions+="    ${LAST_FILE%.*} \\\\\n"
        fi
        LAST_FILE=${firmware_file}
    done
    if [ ! -z ${LAST_FILE} ]; then
        partitions+="    ${LAST_FILE%.*}"
    fi

    LOGI "Generating ${VENDOR_FIRMWARE}/${DEVICE}/config.mk"
    cat <<EOF >"${VENDOR_FIRMWARE}"/"${DEVICE}"/config.mk
FIRMWARE_IMAGES := \\
$(printf "$partitions")

AB_OTA_PARTITIONS += \$(FIRMWARE_IMAGES)
EOF
fi

LOGI "Done!! Check ${VENDOR_FIRMWARE}/${DEVICE} before using it :D"
clean_out
## END OF THE MAGIC ##
