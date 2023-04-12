## Getting Started

    git clone https://github.com/althafvly/lineage_script -b master script

1 - For signed builds, follow these steps

    source script/envsetup.sh
    lunch lineage_alioth-user
    m target-files-package otatools-package generate_verity_key -j$(nproc --all)

2 - Generate keys (Skip this step if you have already generated, make sure its in keys directory)

Create folder new keys

    mkdir -p keys/alioth
    cd keys/alioth
    ../../script/generate_keys.sh

For AVB-1.0+ (eg: sargo- Pixel 3a, aliothin/alioth- Mi 11X/Poco F3)

    openssl genrsa 2048 | openssl pkcs8 -topk8 -scrypt -out avb.pem
    ../../external/avb/avbtool extract_public_key --key avb.pem --output avb_pkmd.bin
    cd ../../

For AVB-1.0 (eg: marlin- Pixel XL)
-  This directory and filename changes per device: kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509

<br>

    ../../out/host/linux-x86/bin/generate_verity_key -convert verity.x509.pem verity_key
    openssl x509 -outform der -in verity.x509.pem -out kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509
    cd ../../

3 - Generate signed build ota and factory image

    script/release.sh alioth

<br>

(Optional) Generate delta packages (Incremental updates)

    bash script/generate_delta.sh alioth \
    out/release-alioth-$OLD_BUILD_NUMBER/lineage_alioth-target_files-$OLD_BUILD_NUMBER.zip \
    out/release-alioth-$NEW_BUILD_NUMBER/lineage_alioth-target_files-$NEW_BUILD_NUMBER.zip

Note:

- Build out directory is out/release-alioth-$BUILD_NUMBER
- Build out for delta is out/release-alioth-$NEW_BUILD_NUMBER
