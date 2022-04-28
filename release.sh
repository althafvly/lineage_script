#!/bin/bash

set -o pipefail

user_error() {
    echo $1 >&2
    exit 1
}

[[ $# -eq 1 ]] || user_error "expected a single argument (device type)"
[[ -n $BUILD_NUMBER ]] || user_error "expected BUILD_NUMBER in the environment"

chrt -b -p 0 $$

PERSISTENT_KEY_DIR=keys/$1
RELEASE_OUT=out/release-$1-$BUILD_NUMBER

# decrypt keys in advance for improved performance and modern algorithm support
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX) || exit 1
trap "rm -rf \"$KEY_DIR\"" EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR" || exit 1
script/decrypt_keys.sh "$KEY_DIR" || exit 1

OLD_PATH="$PATH"
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

rm -rf $RELEASE_OUT || exit 1
mkdir -p $RELEASE_OUT || exit 1
unzip $OUT/otatools.zip -d $RELEASE_OUT/otatools || exit 1

BUILD=$BUILD_NUMBER
VERSION=$BUILD_NUMBER
DEVICE=$1
PRODUCT=$1

TARGET_FILES=$DEVICE-target_files-$BUILD.zip

if [ -f $KEY_DIR/avb.pem ]; then
    AVB_ALGORITHM=SHA256_RSA4096
    [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048
    VERITY_SWITCHES=(--avb_vbmeta_key "$KEY_DIR/avb.pem" --avb_vbmeta_algorithm $AVB_ALGORITHM
        --avb_system_key "$KEY_DIR/avb.pem" --avb_system_algorithm $AVB_ALGORITHM)
elif [ -f $KEY_DIR/verity.x509.pem ]; then
    VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" --replace_verity_private_key "$KEY_DIR/verity"
        --replace_verity_keyid "$KEY_DIR/verity.x509.pem")
fi

$RELEASE_OUT/otatools/releasetools/sign_target_files_apks -o -d "$KEY_DIR" "${VERITY_SWITCHES[@]}" \
    --extra_apks OsuLogin.apk,ServiceWifiResources.apk="$KEY_DIR/releasekey" \
    out/target/product/$DEVICE/obj/PACKAGING/target_files_intermediates/lineage_$DEVICE-target_files-$BUILD_NUMBER.zip \
    $RELEASE_OUT/$TARGET_FILES || exit 1

$RELEASE_OUT/otatools/releasetools/ota_from_target_files -k "$KEY_DIR/releasekey" \
    $RELEASE_OUT/$TARGET_FILES $RELEASE_OUT/lineage_$DEVICE-ota_update-$BUILD.zip || exit 1

$RELEASE_OUT/otatools/releasetools/img_from_target_files $RELEASE_OUT/$TARGET_FILES \
    $RELEASE_OUT/lineage_$DEVICE-img-$BUILD.zip || exit 1

cd $RELEASE_OUT || exit 1
cd ../..
