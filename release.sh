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

# Make sure we have exactly one command-line argument (device type)
[[ $# -eq 1 ]] || print_error "Expected a single argument (device type)"

# Make sure the BUILD_NUMBER and OUT environment variables are set
[[ -n $BUILD_NUMBER ]] || print_error "Expected BUILD_NUMBER in the environment"
[[ -n $OUT ]] || print_error "Expected OUT in the environment"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the paths to the directories containing the keys
COMMON_KEY_DIR=$PWD/keys/common
PERSISTENT_KEY_DIR=$PWD/keys/$1
# Use common keys if it exists
if [ -d $COMMON_KEY_DIR ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
fi

# Set the output directory for the release artifacts
RELEASE_OUT=$PWD/out/release-$1-$BUILD_NUMBER

# Decrypt the keys in advance for improved performance and modern algorithm support
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX)
trap 'rm -rf \"$KEY_DIR\"' EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
"$dir"/decrypt_keys.sh "$KEY_DIR"

# Remove any previous release output and create the release output directory.
rm -rf "$RELEASE_OUT" || exit 1
mkdir -p "$RELEASE_OUT" || exit 1

# Unzip the OTA tools into the output directory and remove it when the script exits.
unzip "$OUT/otatools.zip" -d "$RELEASE_OUT/otatools" || exit 1
trap 'rm -rf \"$RELEASE_OUT/otatools\"' EXIT
cd "$RELEASE_OUT/otatools"

# Add the OTA tools to the PATH
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"
export PATH="$RELEASE_OUT/otatools/bin:$PATH"

# Set the device type
DEVICE=$1

# Set the target files name
TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_NUMBER.zip

# Check if avb.pem exists and set avb algorithm
# Set VERITY_SWITCHES based on the presence of avb.pem or verity.x509.pem.
AVB_ALGORITHM=SHA256_RSA4096
if [ -f "$KEY_DIR"/avb.pem ]; then
  [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048
  VERITY_SWITCHES=(--avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm "$AVB_ALGORITHM" \
      --avb_system_key "$KEY_DIR/avb.pem" --avb_system_algorithm "$AVB_ALGORITHM")
# Check if verity.x509.pem exists and sign target files apks with verity
elif [ -f "$KEY_DIR"/verity.x509.pem ]; then
  VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" \
      --replace_verity_private_key "$KEY_DIR/verity" \
      --replace_verity_keyid "$KEY_DIR/verity.x509.pem")
fi

# Extract the build ID from the build/make/core/build_id.mk file
build_id=$(grep -o 'BUILD_ID=.*' "$dir"/../build/make/core/build_id.mk | cut -d "=" -f 2 | cut -c 1 | tr '[:upper:]' '[:lower:]')

# Check if avb.pem exists or verity.x509.pem exists, Sign the target files apks
# If the build ID is one of 's', or 't', or older and run the appropriate commands for that build
if [[ "$build_id" == [t] ]]; then
    if [ -f $KEY_DIR/avb.pem ]; then
        sign_target_files_apks -o -d "$KEY_DIR" --avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm $AVB_ALGORITHM \
            --extra_apks AdServicesApk.apk="$KEY_DIR/releasekey" \
            --extra_apks Bluetooth.apk="$KEY_DIR/bluetooth" \
            --extra_apks HalfSheetUX.apk="$KEY_DIR/releasekey" \
            --extra_apks OsuLogin.apk="$KEY_DIR/releasekey" \
            --extra_apks SafetyCenterResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceConnectivityResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceUwbResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceWifiResources.apk="$KEY_DIR/releasekey" \
            --extra_apks WifiDialog.apk="$KEY_DIR/releasekey" \
            --extra_apks com.android.adbd.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.adbd.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.apex.cts.shim.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.apex.cts.shim.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.appsearch.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.appsearch.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.art.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.art.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.art.debug.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.art.debug.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.cellbroadcast.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.cellbroadcast.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.conscrypt.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.conscrypt.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.extservices.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.extservices.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.i18n.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.i18n.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.ipsec.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.ipsec.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.media.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.media.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.media.swcodec.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.media.swcodec.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.mediaprovider.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.mediaprovider.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.neuralnetworks.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.neuralnetworks.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.os.statsd.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.os.statsd.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.permission.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.permission.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.resolv.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.resolv.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.runtime.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.runtime.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.scheduling.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.scheduling.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.sdkext.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.sdkext.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.tethering.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.tethering.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.tzdata.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.tzdata.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.vndk.current.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.vndk.current.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.wifi.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.wifi.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.google.pixel.camera.hal.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.google.pixel.camera.hal.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.adservices.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.adservices.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.btservices.apex="$KEY_DIR/bluetooth" \
            --extra_apex_payload_key com.android.btservices.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.compos.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.compos.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.ondevicepersonalization.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.ondevicepersonalization.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.uwb.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.uwb.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.virt.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.virt.apex="$KEY_DIR/avb.pem" \
            "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $RELEASE_OUT/$TARGET_FILES
    elif [ -f $KEY_DIR/verity.x509.pem ]; then
        sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
            --extra_apks AdServicesApk.apk="$KEY_DIR/releasekey" \
            --extra_apks Bluetooth.apk="$KEY_DIR/bluetooth" \
            --extra_apks HalfSheetUX.apk="$KEY_DIR/releasekey" \
            --extra_apks OsuLogin.apk="$KEY_DIR/releasekey" \
            --extra_apks SafetyCenterResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceConnectivityResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceUwbResources.apk="$KEY_DIR/releasekey" \
            --extra_apks ServiceWifiResources.apk="$KEY_DIR/releasekey" \
            --extra_apks WifiDialog.apk="$KEY_DIR/releasekey" \
            "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $RELEASE_OUT/$TARGET_FILES
    fi
elif [[ "$build_id" == [s] ]]; then
    if [ -f $KEY_DIR/avb.pem ]; then
        sign_target_files_apks -o -d "$KEY_DIR" --avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm $AVB_ALGORITHM \
            --extra_apks OsuLogin.apk,ServiceConnectivityResources.apk,ServiceWifiResources.apk="$KEY_DIR/releasekey" \
            --extra_apks com.android.adbd.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.adbd.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.apex.cts.shim.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.apex.cts.shim.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.appsearch.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.appsearch.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.art.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.art.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.art.debug.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.art.debug.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.cellbroadcast.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.cellbroadcast.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.conscrypt.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.conscrypt.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.extservices.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.extservices.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.i18n.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.i18n.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.ipsec.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.ipsec.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.media.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.media.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.media.swcodec.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.media.swcodec.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.mediaprovider.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.mediaprovider.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.neuralnetworks.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.neuralnetworks.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.os.statsd.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.os.statsd.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.permission.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.permission.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.resolv.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.resolv.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.runtime.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.runtime.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.scheduling.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.scheduling.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.sdkext.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.sdkext.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.tethering.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.tethering.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.tzdata.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.tzdata.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.vndk.current.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.vndk.current.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.android.wifi.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.android.wifi.apex="$KEY_DIR/avb.pem" \
            --extra_apks com.google.pixel.camera.hal.apex="$KEY_DIR/releasekey" \
            --extra_apex_payload_key com.google.pixel.camera.hal.apex="$KEY_DIR/avb.pem" \
            "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $RELEASE_OUT/$TARGET_FILES
    elif [ -f $KEY_DIR/verity.x509.pem ]; then
        sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
            --extra_apks OsuLogin.apk,ServiceConnectivityResources.apk,ServiceWifiResources.apk="$KEY_DIR/releasekey" \
            "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $RELEASE_OUT/$TARGET_FILES
    fi
else
    sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
        --extra_apks OsuLogin.apk,ServiceWifiResources.apk="$KEY_DIR/releasekey" \
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $RELEASE_OUT/$TARGET_FILES
fi

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

ota_from_target_files -k "$KEY_DIR/releasekey" "$RELEASE_OUT/$TARGET_FILES" \
    "$RELEASE_OUT/lineage-$LINEAGE_VER-$BUILD_NUMBER-ota_package-$DEVICE-signed.zip" || exit 1

FASTBOOT_PACKAGE="lineage-$LINEAGE_VER-$BUILD_NUMBER-fastboot_package-$DEVICE.zip"
IMAGES=("recovery" "boot" "vendor_boot" "dtbo")

img_from_target_files "$RELEASE_OUT/$TARGET_FILES" "$RELEASE_OUT/$FASTBOOT_PACKAGE"

for i in "${!IMAGES[@]}"; do
    if unzip -l "$RELEASE_OUT/$FASTBOOT_PACKAGE" | grep -q "${IMAGES[i]}.img"; then
        unzip -j -q "$RELEASE_OUT/$FASTBOOT_PACKAGE" "${IMAGES[i]}.img" -d "$RELEASE_OUT"
    fi
done
