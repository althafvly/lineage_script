#!/bin/bash

# Get the directory containing this script
dir="$(dirname "$(realpath "$0")")"

# Source the common file
source "$dir"/common.sh

AVB_ALGORITHM=SHA256_RSA4096
VERITY_SWITCHES=(--replace_verity_public_key "$KEY_DIR/verity_key.pub" \
    --replace_verity_private_key "$KEY_DIR/verity" \
    --replace_verity_keyid "$KEY_DIR/verity.x509.pem")

# Check if avb.pem exists and set avb algorithm
if [ -f $KEY_DIR/avb.pem ]; then
    [[ $(stat -c %s "$KEY_DIR/avb_pkmd.bin") -eq 520 ]] && AVB_ALGORITHM=SHA256_RSA2048

    # Sign the target files apks
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

# Check if verity.x509.pem exists and sign target files apks with verity
elif [ -f $KEY_DIR/verity.x509.pem ]; then

    # Sign the target files apks
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

ota_from_target_files -k "$KEY_DIR/releasekey" "$TARGET_FILES" \
    "lineage-20.0-$BUILD_NUMBER-recovery-$DEVICE-signed.zip"

echo "Do you want to generate fastboot package ?"
read -r -p "Older devices might have issues generating. Yes(y) / Default(n) : " choice
if [ "$choice" = "y" ]; then
    img_from_target_files "$TARGET_FILES" "lineage-20.0-$BUILD_NUMBER-fastboot-$DEVICE-signed.zip"
fi

print "Finished."
