#!/bin/bash

dir="$(dirname "$(realpath "$0")")"
subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=LineageOS/emailAddress=android@android.com'

for cert in releasekey platform shared media networkstack bluetooth sdk_sandbox verity; do \
    "$dir"/make_key.sh "$cert" "$subject"; \
done
