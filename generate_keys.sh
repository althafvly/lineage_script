#!/bin/bash

# Set default values
apex=false
no_pass=false

# Allow decrypted certs and optional apex certs
while getopts ":hanv" opt; do
  case ${opt} in
    h )
      echo "Usage: script.sh [-a] [-n] [-v] [-h]"
      echo "  -a   Optionally generate apex certs"
      echo "  -n   Do not prompt for password"
      echo "  -v   Generate AVB certificate"
      echo "  -h   Display this help message"
      exit 0
      ;;
    a )
      apex=true
      ;;
    n )
      no_pass=true
      ;;
    v )
      avb=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done

# Get the directory path of the script file and store it in the variable "dir"
dir="$(dirname "$(realpath "$0")")"

# Set the subject for the certificates
subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=LineageOS/emailAddress=android@android.com'

# Specify the certs to generate
common="releasekey platform shared media networkstack verity bluetooth sdk_sandbox "
apex_packages="com.android.adbd \
com.android.apex.cts.shim \
com.android.adservices \
com.android.adservices.api \
com.android.appsearch \
com.android.art \
com.android.art.debug \
com.android.bluetooth \
com.android.btservices \
com.android.cellbroadcast \
com.android.compos \
com.android.connectivity.resources \
com.android.conscrypt \
com.android.extservices \
com.android.hotspot2.osulogin \
com.android.i18n \
com.android.ipsec \
com.android.media \
com.android.media.swcodec \
com.android.mediaprovider \
com.android.nearby.halfsheet \
com.android.neuralnetworks \
com.android.ondevicepersonalization \
com.android.os.statsd \
com.android.permission \
com.android.resolv \
com.android.runtime \
com.android.safetycenter.resources \
com.android.scheduling \
com.android.sdkext \
com.android.support.apexer \
com.android.telephony \
com.android.tethering \
com.android.tzdata \
com.android.uwb \
com.android.uwb.resources \
com.android.virt \
com.android.vndk.current \
com.android.wifi \
com.android.wifi.dialog \
com.android.wifi.resources \
com.google.pixel.camera.hal \
com.qorvo.uwb"

# Optionally generate apex
if [ "$apex" = true ]; then
  common+=$apex_packages
fi

if [ "$avb" = true ]; then
  if [ "$no_pass" = true ]; then
    openssl genrsa -out avb.pem 4096
  else
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem
  fi
  ../../external/avb/avbtool extract_public_key --key avb.pem --output avb_pkmd.bin
else
  # Loop through the certificate names and generate keys using the make_key.sh script
  echo "Note: Use same password for all certificates you generate"
  for cert in $common; do \
      no_password=$no_pass "$dir"/make_key.sh "$cert" "$subject"
  done
fi
