#!/bin/bash

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Source the common file
source "$dir"/common.sh

# Specify the apks to sign
sign_releasekey="AdServicesApk.apk,\
HalfSheetUX.apk,\
OsuLogin.apk,\
SafetyCenterResources.apk,\
ServiceConnectivityResources.apk,\
ServiceUwbResources.apk,\
ServiceWifiResources.apk,\
WifiDialog.apk"

# Specify the apex packages to sign
sign_apex="com.android.adservices.apex,\
com.android.adbd.apex,\
com.android.apex.cts.shim.apex,\
com.android.appsearch.apex,\
com.android.art.apex,\
com.android.art.debug.apex,\
com.android.cellbroadcast.apex,\
com.android.compos.apex,\
com.android.conscrypt.apex,\
com.android.extservices.apex,\
com.android.i18n.apex,\
com.android.ipsec.apex,\
com.android.media.apex,\
com.android.mediaprovider.apex,\
com.android.media.swcodec.apex,\
com.android.neuralnetworks.apex,\
com.android.ondevicepersonalization.apex,\
com.android.os.statsd.apex,\
com.android.permission.apex,\
com.android.resolv.apex,\
com.android.runtime.apex,\
com.android.scheduling.apex,\
com.android.sdkext.apex,\
com.android.tethering.apex,\
com.android.tzdata.apex,\
com.android.uwb.apex,\
com.android.virt.apex,\
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
        --extra_apks Bluetooth.apk="$KEY_DIR/bluetooth" \
        --extra_apks com.android.btservices.apex="$KEY_DIR/bluetooth" \
        --extra_apex_payload_key $sign_apex="$KEY_DIR/avb.pem" \
        --extra_apex_payload_key com.android.btservices.apex="$KEY_DIR/avb.pem" \
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" "$TARGET_FILES"

# Check if verity.x509.pem exists and sign target files apks with verity
elif [ -f $KEY_DIR/verity.x509.pem ]; then

    # Sign the target files apks
    sign_target_files_apks -o -d "$KEY_DIR" \
        "${VERITY_SWITCHES[@]}" \
        --extra_apks Bluetooth.apk="$KEY_DIR/bluetooth" \
        --extra_apks $sign_releasekey="$KEY_DIR/releasekey" \
        "$OUT/obj/PACKAGING/target_files_intermediates/$TARGET_FILES" "$TARGET_FILES"
fi

ota_from_target_files -k "$KEY_DIR/releasekey" "$TARGET_FILES" \
    "lineage-20.0-$BUILD_NUMBER-recovery-$DEVICE-signed.zip"

echo "Do you want to generate fastboot package ?"
read -r -p "Older devices might have issues generating. Yes(y) / Default(n) : " choice
if [ "$choice" = "y" ]; then
    img_from_target_files "$TARGET_FILES" "lineage-20.0-$BUILD_NUMBER-fastboot-$DEVICE-signed.zip"
fi

print "Finished."
