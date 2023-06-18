#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Define a function to print an error message and exit
print_error() {
    echo "$1" >&2
    exit 1
}

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Set the device type
if [ -z "$TARGET_PRODUCT" ]; then
    # Make sure we have exactly one command-line argument (device type)
    [[ $# -eq 1 ]] || print_error "Expected a single argument (device type)"
    DEVICE=$1
else
    DEVICE=$(echo "$TARGET_PRODUCT" | cut -d '_' -f 2-)
fi

# Make sure the OUT environment variable set.
[[ -n $OUT ]] || print_error "Expected OUT in the environment"

# Extract the build ID from the build/make/core/build_id.mk file
build_id=$(grep -o 'BUILD_ID=.*' "$LOS_ROOT/build/make/core/build_id.mk" | cut -d "=" -f 2 | cut -c 1 | tr '[:upper:]' '[:lower:]')

# Make sure the BUILD_NUMBER environment variable set. Also build_id is not empty
[[ -n $BUILD_NUMBER ]] || print_error "Expected BUILD_NUMBER in the environment"
[[ -n $build_id ]] || print_error "Run this script in root dir also make sure cloned in [LINEAGEOS_ROOT]/script"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the paths to the directories containing the keys
OLD_COMMON_KEY_DIR=$LOS_ROOT/keys/common
OLD_PERSISTENT_KEY_DIR=$LOS_ROOT/keys/$1
# Use common/device keys dir if it exists
if [ -d "$OLD_PERSISTENT_KEY_DIR" ]; then
    PERSISTENT_KEY_DIR=$OLD_PERSISTENT_KEY_DIR
elif [ -d "$OLD_COMMON_KEY_DIR" ]; then
    PERSISTENT_KEY_DIR=$OLD_COMMON_KEY_DIR
else
    COMMON_KEY_DIR=~/.android-certs
    PERSISTENT_KEY_DIR=~/.android-certs/$DEVICE
    # Use common keys if device dir doesnt exists
    if [ ! -d "$PERSISTENT_KEY_DIR" ]; then
        PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
    fi
fi

# Decrypt the keys in advance for improved performance and modern algorithm support
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR="$OUT/keys"
cp -r "$PERSISTENT_KEY_DIR" "$KEY_DIR"
"$dir"/crypt_keys.sh -d "$KEY_DIR"

# Define a function to delete temp directories
cleanup() {
  echo "Cleaning up..."
  rm -rf "$KEY_DIR" "$OUT/otatools"
  exit 1
}

# Unzip the OTA tools into the output directory and remove it when the script exits.
unzip "$OUT/otatools.zip" -d "$OUT/otatools" || exit 1
cd "$OUT/otatools"

# Registering the cleanup function for script failure and interruption
trap cleanup ERR SIGINT SIGTERM

# Add the OTA tools to the PATH
export PATH="$LOS_ROOT/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$LOS_ROOT/prebuilts/build-tools/path/linux-x86:$PATH"
export PATH="$OUT/otatools/bin:$PATH"

# Set the target files name
TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_NUMBER.zip

APEX_PACKAGE_LIST=(
    "com.android.adbd"
    "com.android.adservices"
    "com.android.adservices.api"
    "com.android.appsearch"
    "com.android.art"
    "com.android.bluetooth"
    "com.android.btservices"
    "com.android.cellbroadcast"
    "com.android.compos"
    "com.android.connectivity.resources"
    "com.android.conscrypt"
    "com.android.extservices"
    "com.android.hotspot2.osulogin"
    "com.android.i18n"
    "com.android.ipsec"
    "com.android.media"
    "com.android.media.swcodec"
    "com.android.mediaprovider"
    "com.android.nearby.halfsheet"
    "com.android.neuralnetworks"
    "com.android.ondevicepersonalization"
    "com.android.os.statsd"
    "com.android.permission"
    "com.android.resolv"
    "com.android.runtime"
    "com.android.safetycenter.resources"
    "com.android.scheduling"
    "com.android.sdkext"
    "com.android.support.apexer"
    "com.android.telephony"
    "com.android.tethering"
    "com.android.tzdata"
    "com.android.uwb"
    "com.android.uwb.resources"
    "com.android.virt"
    "com.android.vndk.current"
    "com.android.wifi"
    "com.android.wifi.dialog"
    "com.android.wifi.resources"
    "com.google.pixel.camera.hal"
    "com.qorvo.uwb"
)

if [[ "$build_id" == [t] ]]; then
    LINEAGE_VER=20.0
elif [[ "$build_id" == [s] ]]; then
    LINEAGE_VER=19.1
elif [[ "$build_id" == [r] ]]; then
    LINEAGE_VER=18.1
elif [[ "$build_id" == [q] ]]; then
    LINEAGE_VER=17.1
elif [[ "$build_id" == [p] ]]; then
    LINEAGE_VER=16.0
elif [[ "$build_id" == [o] ]]; then
    LINEAGE_VER=15.1
else
    # default value if none of the above conditions are met
    LINEAGE_VER=14.1
fi

# Check if avb.pem exists and set avb algorithm
# Set VERITY_SWITCHES based on the presence of avb.pem or verity.x509.pem.
AVB_ALGORITHM=SHA256_RSA4096
if [ -f "$KEY_DIR"/avb.pem ]; then
    [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048
    VERITY_SWITCHES=( --avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm "$AVB_ALGORITHM" )
    if [[ "$build_id" != [st] ]]; then
        VERITY_SWITCHES+=( --avb_system_key "$KEY_DIR/avb.pem" --avb_system_algorithm "$AVB_ALGORITHM" )
    fi
# Check if verity.x509.pem exists and sign target files apks with verity
elif [ -f "$KEY_DIR"/verity.x509.pem ]; then
    VERITY_SWITCHES=( --replace_verity_public_key "$KEY_DIR/verity_key.pub"
        --replace_verity_private_key "$KEY_DIR/verity"
        --replace_verity_keyid "$KEY_DIR/verity.x509.pem" )
fi

SIGN_TARGETS=( "${VERITY_SWITCHES[@]}" )

if [[ "$build_id" == [rst] ]]; then
    PACKAGE_LIST=(
        "OsuLogin"
        "ServiceWifiResources"
    )
    if [[ "$build_id" == [st] ]]; then
        PACKAGE_LIST+=(
            "ServiceConnectivityResources"
        )
        if [[ "$build_id" == [t] ]]; then
            PACKAGE_LIST+=(
                "AdServicesApk"
                "HalfSheetUX"
                "SafetyCenterResources"
                "ServiceUwbResources"
                "WifiDialog"
            )
        fi

        if [ -f "$KEY_DIR/avb.pem" ]; then
            for PACKAGE in "${APEX_PACKAGE_LIST[@]}"; do
                if [ -f "$KEY_DIR/$PACKAGE" ] && [ -f "$KEY_DIR/$PACKAGE.pem" ]; then
                    SIGN_TARGETS+=( --extra_apks "$PACKAGE.apex=$KEY_DIR/$PACKAGE"
                        --extra_apex_payload_key "$PACKAGE.apex=$KEY_DIR/$PACKAGE.pem" )
                else
                    SIGN_TARGETS+=( --extra_apks "$PACKAGE.apex=$KEY_DIR/releasekey"
                        --extra_apex_payload_key "$PACKAGE.apex=$KEY_DIR/avb.pem" )
                fi
            done
        fi
    fi

    for PACKAGE in "${PACKAGE_LIST[@]}"; do
        SIGN_TARGETS+=( --extra_apks "$PACKAGE.apk=$KEY_DIR/releasekey" )
    done
fi

sign_target_files_apks -o -d "$KEY_DIR" "${SIGN_TARGETS[@]}" \
    "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" "$OUT/$TARGET_FILES"

ota_from_target_files -k "$KEY_DIR/releasekey" "$OUT/$TARGET_FILES" \
    "$OUT/lineage-$LINEAGE_VER-$BUILD_NUMBER-ota_package-$DEVICE-signed.zip" || exit 1

FASTBOOT_PACKAGE="lineage-$LINEAGE_VER-$BUILD_NUMBER-fastboot_package-$DEVICE.zip"
IMAGES=("recovery" "boot" "vendor_boot" "dtbo")

img_from_target_files "$OUT/$TARGET_FILES" "$OUT/$FASTBOOT_PACKAGE"

for i in "${!IMAGES[@]}"; do
    if unzip -l "$OUT/$FASTBOOT_PACKAGE" | grep -q "${IMAGES[i]}.img"; then
        unzip -o -j -q "$OUT/$FASTBOOT_PACKAGE" "${IMAGES[i]}.img" -d "$OUT"
        mv "$OUT/${IMAGES[i]}.img" "$OUT/lineage-$LINEAGE_VER-$BUILD_NUMBER-${IMAGES[i]}-$DEVICE.img"
    fi
done

cleanup
