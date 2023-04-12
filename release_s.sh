#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Define a function to print an error message and exit
print() {
    echo "$1" >&2
    exit 1
}

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Make sure we have exactly one command-line argument (device type)
[[ $# -eq 1 ]] || print "Expected a single argument (device type)"

# Make sure the BUILD_NUMBER and OUT environment variables are set
[[ -n $BUILD_NUMBER ]] || print "Expected BUILD_NUMBER in the environment"
[[ -n $OUT ]] || print "Expected OUT in the environment"

# Set the scheduling policy of this script to "batch" for better performance
chrt -b -p 0 $$

# Set the paths to the directories containing the keys
COMMON_KEY_DIR=keys/common
PERSISTENT_KEY_DIR=keys/$1
if [ -d $COMMON_KEY_DIR ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
fi

# Set the output directory for the release artifacts
RELEASE_OUT=out/release-$1-$BUILD_NUMBER

# Decrypt the keys in advance for improved performance and modern algorithm support
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX)
trap 'rm -rf \"$KEY_DIR\" && rm -f \"$PWD/$RELEASE_OUT/keys\"' EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
"$dir"/script/decrypt_keys.sh "$KEY_DIR"

# Add the build tools to the PATH
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

# Remove any existing release artifacts and create the output directory
rm -rf "$RELEASE_OUT"
mkdir -p "$RELEASE_OUT"

# Unzip the OTA tools into the output directory
unzip "$OUT/otatools.zip" -d "$RELEASE_OUT"
cd "$RELEASE_OUT"

# Create a symbolic link to the keys directory for use with otacerts.zip
ln -s "$KEY_DIR" keys
KEY_DIR=keys

# Add the OTA tools to the PATH
export PATH="$PWD/bin:$PATH"

# Set the device type
DEVICE=$1

# Set the target files name
TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_NUMBER.zip

# Specify the apks to sign
sign_releasekey="OsuLogin.apk,\
ServiceConnectivityResources.apk,\
ServiceWifiResources.apk"

# Specify the apex packages to sign
sign_apex="com.android.adbd.apex,\
com.android.apex.cts.shim.apex,\
com.android.appsearch.apex,\
com.android.art.apex,\
com.android.art.debug.apex,\
com.android.cellbroadcast.apex,\
com.android.conscrypt.apex,\
com.android.extservices.apex,\
com.android.i18n.apex,\
com.android.ipsec.apex,\
com.android.media.apex,\
com.android.mediaprovider.apex,\
com.android.media.swcodec.apex,\
com.android.neuralnetworks.apex,\
com.android.os.statsd.apex,\
com.android.permission.apex,\
com.android.resolv.apex,\
com.android.runtime.apex,\
com.android.scheduling.apex,\
com.android.sdkext.apex,\
com.android.tethering.apex,\
com.android.tzdata.apex,\
com.android.vndk.current.apex,\
com.android.wifi.apex,\
com.google.pixel.camera.hal.apex"

AVB_ALGORITHM=SHA256_RSA4096
VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" \
    --replace_verity_private_key "$KEY_DIR/verity" \
    --replace_verity_keyid "$KEY_DIR/verity.x509.pem")

# Check if avb.pem exists and set avb algorithm
if [ -f $KEY_DIR/avb.pem ]; then
    [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048

    # Sign the target files apks
    sign_target_files_apks -o -d "$KEY_DIR" \
        --avb_vbmeta_key "$KEY_DIR/avb.pem" \
        --avb_vbmeta_algorithm $AVB_ALGORITHM \
        --extra_apks $sign_releasekey="$KEY_DIR/releasekey" \
        --extra_apks $sign_apex="$KEY_DIR/releasekey" \
        --extra_apex_payload_key $sign_apex="$KEY_DIR/avb.pem" \
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" "$TARGET_FILES"

# Check if verity.x509.pem exists and sign target files apks with verity
elif [ -f $KEY_DIR/verity.x509.pem ]; then

    # Sign the target files apks
    sign_target_files_apks -o -d "$KEY_DIR" \
        "${VERITY_SWITCHES[@]}" \
        --extra_apks $sign_releasekey="$KEY_DIR/releasekey" \
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" "$TARGET_FILES"
fi

ota_from_target_files -k "$KEY_DIR/releasekey" "$TARGET_FILES" \
    "lineage-19.1-$BUILD_NUMBER-recovery-$DEVICE-signed.zip"

echo "Do you want to generate fastboot package ?"
read -r -p "Older devices might have issues generating. Yes(y) / Default(n) : " choice
if [ "$choice" = "y" ]; then
    img_from_target_files "$TARGET_FILES" "lineage-19.1-$BUILD_NUMBER-fastboot-$DEVICE-signed.zip"
fi

print "Finished."
