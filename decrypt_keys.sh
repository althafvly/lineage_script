#!/bin/bash

# Set bash options to exit script if any command fails, if any variable is unset, or if any command in a pipeline fails
set -o errexit -o nounset -o pipefail

# Define function for user errors
user_error() {
    echo "$1" >&2
    exit 1
}

# Check that the user has provided one argument (key directory)
[[ $# -ne 1 ]] && user_error "expected 1 argument (key directory)"

# Change to the provided key directory
cd "$1"

# Prompt for key password if not defined
[[ "${password+defined}" = defined ]] || read -r -p "Enter key passphrase (empty if none): " -s password
echo

# Create a temporary directory and set a trap to delete it when the script exits
tmp="$(mktemp -d /dev/shm/decrypt_keys.XXXXXXXXXX)"

# Set the password environment variable
export password

# Decrypt each key in the directory
for key in releasekey platform shared media networkstack bluetooth sdk_sandbox verity; do
    if [[ -f $key.pk8 ]]; then
        if [[ -n $password ]]; then
            openssl pkcs8 -inform DER -in $key.pk8 -passin env:password | openssl pkcs8 -topk8 -outform DER -out "$tmp/$key.pk8" -nocrypt
        else
            openssl pkcs8 -topk8 -inform DER -in $key.pk8 -outform DER -out "$tmp/$key.pk8" -nocrypt
        fi
    fi
done

# Decrypt avb.pem if it exists in the directory
if [[ -f avb.pem ]]; then
    if [[ -n $password ]]; then
        openssl pkcs8 -topk8 -in avb.pem -passin env:password -out "$tmp/avb.pem" -nocrypt
    else
        openssl pkcs8 -topk8 -in avb.pem -out "$tmp/avb.pem" -nocrypt
    fi
fi

# Unset the password environment variable
unset password

# Move the decrypted keys to the original directory
mv "$tmp"/* .
rm -rf "$tmp"
