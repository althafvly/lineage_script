#!/bin/bash

set -o errexit -o nounset -o pipefail

user_error() {
    echo $1 >&2
    exit 1
}

[[ $# -eq 3 ]] || user_error "expected 3 arguments (device, old_target.zip, new_target.zip)"

chrt -b -p 0 $$

PERSISTENT_KEY_DIR=keys/$1
DEVICE=$1
OLDZIP=$2
NEWZIP=$3
OTADIR=${NEWZIP%/*}

# decrypt keys in advance for improved performance and modern algorithm support
KEY_DIR=$(mktemp -d --tmpdir delta_keys.XXXXXXXXXX)
trap "rm -rf \"$KEY_DIR\"" EXIT
cp "$PERSISTENT_KEY_DIR"/* "$KEY_DIR"
script/decrypt_keys.sh "$KEY_DIR"

export PATH="$PWD/prebuilts/build-tools/linux-x86/bin:$PATH"
export PATH="$PWD/prebuilts/build-tools/path/linux-x86:$PATH"

ota_from_target_files "${EXTRA_OTA[@]}" -k "$KEY_DIR/releasekey" \
    -i $OLDZIP $NEWZIP $OTADIR/$DEVICE-incremental-$(date +'%m-%d-%Y').zip
