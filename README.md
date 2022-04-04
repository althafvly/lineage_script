Getting Started
---------------

    git clone https://github.com/althafvly/lineage_script script

For signed builds you need to generate keys, follow these steps

For AVB-1.0+

    mkdir -p keys/sargo
    cd keys/sargo
    ../../development/tools/make_key releasekey '/CN=LineageOS/'
    ../../development/tools/make_key platform '/CN=LineageOS/'
    ../../development/tools/make_key shared '/CN=LineageOS/'
    ../../development/tools/make_key media '/CN=LineageOS/'
    ../../development/tools/make_key networkstack '/CN=LineageOS/'
    openssl genrsa 4096 | openssl pkcs8 -topk8 -scrypt -out avb.pem
    ../../external/avb/avbtool extract_public_key --key avb.pem --output avb_pkmd.bin
    cd ../..

For AVB-1.0

    mkdir -p keys/marlin
    cd keys/marlin
    ../../development/tools/make_key releasekey '/CN=LineageOS/'
    ../../development/tools/make_key platform '/CN=LineageOS/'
    ../../development/tools/make_key shared '/CN=LineageOS/'
    ../../development/tools/make_key media '/CN=LineageOS/'
    ../../development/tools/make_key networkstack '/CN=LineageOS/'
    ../../development/tools/make_key verity '/CN=LineageOS/'
    cd ../..

    make -j8 generate_verity_key
    out/host/linux-x86/bin/generate_verity_key -convert keys/marlin/verity.x509.pem keys/marlin/verity_key
    openssl x509 -outform der -in keys/marlin/verity.x509.pem -out kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509

  To Build rom (factory and ota build)

    source script/envsetup.sh
    lunch lineage_marlin-user
    m target-files-package otatools-package && script/release.sh marlin
