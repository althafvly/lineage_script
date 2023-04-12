#!/bin/bash

# Enable strict error checking and exit on error or pipe failure
set -o errexit -o pipefail

# Function to print an error message and exit with a status of 1.
user_error() {
  echo "$1" >&2
  exit 1
}

# Get the directory containing the script and make sure we have one argument (device type).
# Also, make sure that the BUILD_NUMBER environment variable is set.
dir="$(dirname "$(realpath "$0")")"
[[ $# -eq 1 ]] || user_error "expected a single argument (device type)"
[[ -n $BUILD_NUMBER ]] || user_error "expected BUILD_NUMBER in the environment"

# Set the PERSISTENT_KEY_DIR and RELEASE_OUT variables based on the device type and build number.
PERSISTENT_KEY_DIR=keys/$1
RELEASE_OUT=out/release-$1-$BUILD_NUMBER

# Decrypt keys in advance for improved performance and modern algorithm support.
# Copy the keys to a temporary directory and remove it when the script exits.
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX) || exit 1
trap 'rm -rf \"$KEY_DIR\"' EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR" || exit 1
"$dir"/script/decrypt_keys.sh "$KEY_DIR" || exit 1

# Set the PATH environment variable to include the build tools.
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

# Remove any previous release output and create the release output directory.
rm -rf "$RELEASE_OUT" || exit 1
mkdir -p "$RELEASE_OUT" || exit 1

# Unzip the otatools.zip file to the release output directory.
unzip "$OUT/otatools.zip" -d "$RELEASE_OUT/otatools" || exit 1

# Set the BUILD and DEVICE variables based on the device type and build number.
BUILD=$BUILD_NUMBER
DEVICE=$1

# Set VERITY_SWITCHES based on the presence of avb.pem or verity.x509.pem.
if [ -f "$KEY_DIR"/avb.pem ]; then
  AVB_ALGORITHM=SHA256_RSA4096
  [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048
  VERITY_SWITCHES=(--avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm "$AVB_ALGORITHM" \
      --avb_system_key "$KEY_DIR/avb.pem" --avb_system_algorithm "$AVB_ALGORITHM")
elif [ -f "$KEY_DIR"/verity.x509.pem ]; then
  VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" \
      --replace_verity_private_key "$KEY_DIR/verity" \
      --replace_verity_keyid "$KEY_DIR/verity.x509.pem")
fi

"$RELEASE_OUT"/otatools/releasetools/sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
    --extra_apks OsuLogin.apk,ServiceWifiResources.apk="$KEY_DIR/releasekey" \
    out/target/product/"$DEVICE"/obj/PACKAGING/target_files_intermediates/lineage_"$DEVICE"-target_files-"$BUILD_NUMBER".zip \
    "$RELEASE_OUT"/"$TARGET_FILES" || exit 1

"$RELEASE_OUT"/otatools/releasetools/ota_from_target_files -k "$KEY_DIR/releasekey" \
    "$RELEASE_OUT/$TARGET_FILES" "$RELEASE_OUT"/lineage_"$DEVICE"-ota_update-"$BUILD".zip || exit 1

echo "Do you want to generate fastboot package ?"
read -r -p "Older devices might have issues generating. Yes(y) / Default(n) : " choice
if [ "$choice" = "y" ]; then
    "$RELEASE_OUT"/otatools/releasetools/img_from_target_files "$RELEASE_OUT/$TARGET_FILES" \
        "$RELEASE_OUT/lineage_$DEVICE-img-$BUILD.zip" || exit 1
fi

cd "$RELEASE_OUT" || exit 1
cd ../..

print "Finished."
