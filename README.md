## Getting Started

    git clone https://github.com/althafvly/lineage_script script

1 - For signed builds you need to generate keys, follow these steps

    source script/envsetup.sh
    lunch lineage_alioth-user

2 - Generate keys (Skip this step if you have already generated, make sure its in keys directory)

Create folder new keys

    mkdir -p keys/alioth
    cd keys/alioth

Generate keys to sign apks

    ../../development/tools/make_key bluetooth '/CN=LineageOS/'
    ../../development/tools/make_key releasekey '/CN=LineageOS/'
    ../../development/tools/make_key sdk_sandbox '/CN=LineageOS/'
    ../../development/tools/make_key platform '/CN=LineageOS/'
    ../../development/tools/make_key shared '/CN=LineageOS/'
    ../../development/tools/make_key media '/CN=LineageOS/'
    ../../development/tools/make_key networkstack '/CN=LineageOS/'
    cd ../..

For AVB-1.0+ (eg: sargo- Pixel 3a, aliothin/alioth- Mi 11X/Poco F3)

    openssl genrsa 2048 | openssl pkcs8 -topk8 -scrypt -out keys/alioth/avb.pem
    ../../external/avb/avbtool extract_public_key --key keys/alioth/avb.pem --output keys/alioth/avb_pkmd.bin

For AVB-1.0 (eg: marlin- Pixel XL)

    cd keys/marlin
    ../../development/tools/make_key verity '/CN=LineageOS/'
    cd ../..
    make -j8 generate_verity_key
    out/host/linux-x86/bin/generate_verity_key -convert keys/marlin/verity.x509.pem keys/marlin/verity_key
    openssl x509 -outform der -in keys/marlin/verity.x509.pem -out kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509

3 - Build (factory and ota build)

    m target-files-package otatools-package -j$(nproc --all)
    script/release.sh alioth

4 - (Optional) Generate delta packages (Incremental updates)

    bash script/generate_delta.sh alioth \
    out/release-alioth-$OLD_BUILD_NUMBER/lineage_alioth-target_files-$OLD_BUILD_NUMBER.zip \
    out/release-alioth-$NEW_BUILD_NUMBER/lineage_alioth-target_files-$NEW_BUILD_NUMBER.zip

Note:

- Build out directory is out/release-alioth-$BUILD_NUMBER
- Build out for delta is out/release-alioth-$NEW_BUILD_NUMBER
