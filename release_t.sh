#!/bin/bash

set -o errexit -o pipefail

print() {
    echo $1 >&2
    exit 1
}

dir="$(dirname "$(realpath "$0")")"

[[ $# -eq 1 ]] || print "expected a single argument (device type)"
[[ -n $BUILD_NUMBER ]] || print "expected BUILD_NUMBER in the environment"
[[ -n $OUT ]] || print "expected OUT in the environment"

chrt -b -p 0 $$

COMMON_KEY_DIR=keys/common
PERSISTENT_KEY_DIR=keys/$1
if [ -d COMMON_KEY_DIR ]; then
    PERSISTENT_KEY_DIR=$COMMON_KEY_DIR
fi
RELEASE_OUT=out/release-$1-$BUILD_NUMBER

# decrypt keys in advance for improved performance and modern algorithm support
KEY_DIR=$(mktemp -d /dev/shm/release_keys.XXXXXXXXXX)
trap "rm -rf \"$KEY_DIR\" && rm -f \"$PWD/$RELEASE_OUT/keys\"" EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
$dir/script/decrypt_keys.sh "$KEY_DIR"

OLD_PATH="$PATH"
export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

rm -rf $RELEASE_OUT
mkdir -p $RELEASE_OUT
unzip $OUT/otatools.zip -d $RELEASE_OUT
cd $RELEASE_OUT

# reproducible key path for otacerts.zip
ln -s "$KEY_DIR" keys
KEY_DIR=keys

export PATH="$PWD/bin:$PATH"

DEVICE=$1

TARGET_FILES=lineage_$DEVICE-target_files-$BUILD_NUMBER.zip

if [ -f $KEY_DIR/avb.pem ]; then
    AVB_ALGORITHM=SHA256_RSA4096
    [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048
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
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $TARGET_FILES
elif [ -f $KEY_DIR/verity.x509.pem ]; then
    VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" --replace_verity_private_key "$KEY_DIR/verity"
        --replace_verity_keyid "$KEY_DIR/verity.x509.pem")
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
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" $TARGET_FILES
fi

ota_from_target_files -k "$KEY_DIR/releasekey" $TARGET_FILES \
    lineage-20.0-$BUILD_NUMBER-recovery-$DEVICE-signed.zip

echo "Do you want to generate fastboot package ?"
read -p "Older devices might have issues generating. Yes(y) / Default(n) : " choice
if [ "$choice" = "y" ]; then
    img_from_target_files $TARGET_FILES lineage-20.0-$BUILD_NUMBER-fastboot-$DEVICE-signed.zip
fi

print "Finished."
