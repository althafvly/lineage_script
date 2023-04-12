#!/bin/bash

# Set bash options
set -o errexit -o nounset -o pipefail

# Function to print error message and exit with code 1
user_error() {
    echo "$1" >&2
    exit 1
}

# Ensure that a single argument, the key directory, is passed in
[[ $# -ne 1 ]] && user_error "expected 1 argument (key directory)"

# Move to the key directory
cd "$1"

# Prompt user for old and new key passphrases
read -r -p "Enter old key passphrase (empty if none): " -s password
echo
read -r -p "Enter new key passphrase: " -s new_password
echo
read -r -p "Confirm new key passphrase: " -s confirm_new_password
echo

# Verify that the new passphrase is correctly entered twice
if [[ "$new_password" != "$confirm_new_password" ]]; then
    echo "new password does not match"
    exit 1
fi

# Create a temporary directory for the encrypted keys
tmp="$(mktemp -d /dev/shm/encrypt_keys.XXXXXXXXXX)"
trap 'rm -rf \"$tmp\"' EXIT

# Export password and new_password for openssl to use
export password
export new_password

# Loop through keys and encrypt with new passphrase
for key in releasekey platform shared media networkstack bluetooth sdk_sandbox verity; do
    if [[ -f $key.pk8 ]]; then
        if [[ -n $password ]]; then
            openssl pkcs8 -inform DER -in $key.pk8 -passin env:password | openssl pkcs8 -topk8 -outform DER -out "$tmp/$key.pk8" -passout env:new_password -scrypt
        else
            openssl pkcs8 -topk8 -inform DER -in $key.pk8 -outform DER -out "$tmp/$key.pk8" -passout env:new_password -scrypt
        fi
    fi
done

# Encrypt avb.pem with new passphrase
if [[ -f avb.pem ]]; then
    if [[ -n $password ]]; then
        openssl pkcs8 -topk8 -in avb.pem -passin env:password -out "$tmp/avb.pem" -passout env:new_password -scrypt
    else
        openssl pkcs8 -topk8 -in avb.pem -out "$tmp/avb.pem" -passout env:new_password -scrypt
    fi
fi

# Unset password and new_password
unset password
unset new_password

# Move encrypted keys from temp directory to key directory
mv "$tmp"/* .
