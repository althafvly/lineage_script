#!/bin/bash

# Set bash options
set -o errexit -o nounset -o pipefail

# Function to print error message and exit with code 1
print_error() {
  echo "$1" >&2
  exit 1
}

encrypt=false
decrypt=false
check=false

while getopts "edcp:" opt; do
  case $opt in
  e)
    # Encoding option selected
    encrypt=true
    ;;
  d)
    # Decoding option selected
    decrypt=true
    ;;
  c)
    # Check option selected
    check=true
    ;;
  p)
    password="$OPTARG"
    ;;
  \?)
    # Invalid option selected
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

dir="$(dirname "$(realpath "$0")")"

if ! $encrypt && ! $decrypt && ! $check; then
  echo "Usage: $(basename "$0") [-e | -d | -c] [-p password] key_directory output_directory"
  echo "  -e: Encrypt the keys"
  echo "  -d: Decrypt the keys"
  echo "  -c: Check decrypted keys"
  echo "  -p: Key passphrase (optional; will prompt if not provided)"
  exit 1
fi

cert_list=$(<"$dir/common.list")
cert_list+=$(<"$dir/apex.list")

# Shift the options so that $1 is the first argument after the options
shift $((OPTIND - 1))

# Ensure that a single argument, the key directory, is passed in
[[ $# -ne 2 ]] && print_error "expected 2 arguments (key directory, output directory)"

key_dir="$(realpath "$1")"
out_dir="$(realpath "$2")"
mkdir -p "$out_dir"

if ( $encrypt || $decrypt ); then
  # Prompt for key password if not defined
  if [[ -z "${password:-}" ]]; then
    read -r -p "Enter key passphrase (empty if none): " -s password
    echo
  fi

  # Export password for openssl to use
  export password
fi

if $encrypt; then
  # Prompt user for old and new key passphrases
  read -r -p "Enter new key passphrase: " -s new_password
  echo
  read -r -p "Confirm new key passphrase: " -s confirm_new_password
  echo

  # Verify that the new passphrase is correctly entered twice
  if [[ "$new_password" != "$confirm_new_password" ]]; then
    print_error "New password does not match"
  fi

  # Export new_password for openssl to use
  export new_password

  # Loop through keys and encrypt with new passphrase
  for key in $cert_list; do
    if [[ -f "$key_dir/$key.pk8" ]]; then
      echo "Ecrypting key: $key"
      if [[ -n $password ]]; then
        openssl pkcs8 -inform DER -in $key_dir/$key.pk8 -passin env:password | openssl pkcs8 -topk8 -outform DER -out "$out_dir/$key.pk8" -passout env:new_password -scrypt
      else
        openssl pkcs8 -topk8 -inform DER -in $key_dir/$key.pk8 -outform DER -out "$out_dir/$key.pk8" -passout env:new_password -scrypt
      fi
    fi
  done

  # Encrypt avb.pem with new passphrase
  if [[ -f $key_dir/avb.pem ]]; then
    echo "Ecrypting key: avb"
    if [[ -n $password ]]; then
      openssl pkcs8 -topk8 -in $key_dir/avb.pem -passin env:password -out "$out_dir/avb.pem" -passout env:new_password -scrypt
    else
      openssl pkcs8 -topk8 -in $key_dir/avb.pem -out "$out_dir/avb.pem" -passout env:new_password -scrypt
    fi
  fi

  # Unset new_password
  unset new_password
elif $decrypt; then
  # Decrypt each key in the directory
  for key in $cert_list; do
    if [[ -f $key_dir/$key.pk8 ]]; then
      echo "Decrypting key: $key"
      if [[ -n $password ]]; then
        openssl pkcs8 -inform DER -in $key_dir/$key.pk8 -passin env:password | openssl pkcs8 -topk8 -outform DER -out "$out_dir/$key.pk8" -nocrypt
        openssl pkcs8 -inform DER -nocrypt -in "$out_dir/$key.pk8" -out "$out_dir/$key.pem"
      else
        openssl pkcs8 -topk8 -inform DER -in $key_dir/$key.pk8 -outform DER -out "$out_dir/$key.pk8" -nocrypt
      fi
    fi
  done

  # Decrypt avb.pem if it exists in the directory
  if [[ -f $key_dir/avb.pem ]]; then
    echo "Decrypting key: avb"
    if [[ -n $password ]]; then
      openssl pkcs8 -topk8 -in $key_dir/avb.pem -passin env:password -out "$out_dir/avb.pem" -nocrypt
    else
      openssl pkcs8 -topk8 -in $key_dir/avb.pem -out "$out_dir/avb.pem" -nocrypt
    fi
  fi
elif $check; then
  echo "Checking keys in: $1"
  for key in $cert_list; do
      [[ -f "$key_dir/$key.pk8" ]] || continue
      echo "Checking key: $key"

      openssl pkcs8 -inform DER -nocrypt -in "$key_dir/$key.pk8" -out /dev/null 2>/dev/null

      if [[ $? -ne 0 ]]; then
          echo "$key failed"
      fi
  done
  echo "Done"
fi

# Unset the password environment variable
unset password

