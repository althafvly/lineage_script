#!/bin/bash

apex=false
no_pass=false
avb=false
force=false

# Parse CLI options
while getopts ":hanvf" opt; do
  case ${opt} in
    h)
      echo "Usage: $0 [-a] [-n] [-f] [-v] [-h]"
      echo "  -a   Generate APEX certs"
      echo "  -n   Do not prompt for password"
      echo "  -v   Generate AVB certificate"
      echo "  -f   Force overwrite existing certificates"
      echo "  -h   Show this help message"
      exit 0
      ;;
    a) apex=true ;;
    n) no_pass=true ;;
    v) avb=true ;;
    f) force=true ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

dir="$(dirname "$(realpath "$0")")"

subject='/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=LineageOS/emailAddress=android@android.com'

if $apex; then
  cert_list=$(<"$dir/apex.list")
else
  cert_list=$(<"$dir/common.list")
fi

if [ "$no_pass" != true ]; then
  read -rsp "Enter password for certificate keys (leave blank for no password): " password
  echo
else
  password=""
fi
readonly password

generate_cert() {
  local name="$1"
  local keysize=4096
  [[ "$name" == "verity" ]] && keysize=2048

  if [[ -e "$name.pk8" || -e "$name.x509.pem" ]]; then
    if ! $force; then
      echo "File '$name' exists. Skipping (use -f to overwrite)."
      return
    else
      echo "Overwriting existing certificate: $name"
    fi
  fi

  echo "Generating cert: $name ($keysize-bit RSA)"

  openssl genrsa -out "$name.key" "$keysize"

  openssl req -new -x509 -sha256 -key "$name.key" -out "$name.x509.pem" \
    -days 10000 -subj "$subject"

  if [[ -z "$password" ]]; then
    openssl pkcs8 -in "$name.key" -topk8 -outform DER -out "$name.pk8" -nocrypt
  else
    openssl pkcs8 -in "$name.key" -topk8 -v1 PBE-SHA1-3DES -outform DER \
      -out "$name.pk8" -passout pass:"$password"
  fi

  if $apex; then
    if [[ -z "$password" ]]; then
      openssl pkcs8 -in "$name.pk8" -inform DER -out "$name.pem" -nocrypt
    else
      openssl pkcs8 -in "$name.pk8" -inform DER -out "$name.pem" -passin pass:"$password"
    fi
  fi

  rm -f "$name.key"
}

if $avb; then
  echo "Generating AVB key..."

  if [[ -e "avb.pem" || -e "avb_pkmd.bin" ]]; then
    if ! $force; then
      echo "AVB key files exist. Skipping (use -f to overwrite)."
      exit 0
    else
      echo "Overwriting existing AVB key files due to -f"
    fi
  fi

  if [[ -z "$password" ]]; then
    openssl genrsa -out avb.pem 4096
    python3 $dir/extract_public_key.py --key avb.pem --output avb_pkmd.bin
  else
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem -passout pass:"$password"
    python3 $dir/extract_public_key.py --key avb.pem --output avb_pkmd.bin --password "$password"
  fi

  exit 0
fi

for cert in $cert_list; do
  generate_cert "$cert"
done
