#!/bin/bash

# Get the directory path of the script file and store it in the variable "dir"
dir="$(dirname "$(realpath "$0")")"

# Set the subject for the certificates
subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=LineageOS/emailAddress=android@android.com'

# Loop through the certificate names and generate keys using the make_key.sh script
for cert in releasekey platform shared media networkstack bluetooth sdk_sandbox verity; do \
    "$dir"/make_key.sh "$cert" "$subject"; \
done
