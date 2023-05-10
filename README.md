## Getting Started

1. Clone the repository using the following command:
    ```
    git clone https://github.com/althafvly/lineage_script -b master script
    ```
2. For signed builds, follow these steps:

    - Set up the environment by running the following command:
    ```
    source script/envsetup.sh
    ```
    - Choose the target device using the following command and selecting the appropriate option:
    ```
    lunch lineage_alioth-user
    ```
    - Generate the target files package, otatools package, and verity key using the following command:
    ```
    make target-files-package otatools-package generate_verity_key -j$(nproc --all)
    ```
3. Generate keys (Skip this step if you have already generated keys. Make sure they are in the keys directory).

    - Create a new folder for the keys:
    ```
    mkdir -p keys/alioth
    cd keys/alioth
    ```
    - Run the generate_keys.sh script to generate the keys:
    ```
    Usage: generate_keys.sh [-a] [-n] [-h]
      -a   Optionally generate apex certs
      -n   Do not prompt for password
      -v   Generate AVB certificate
      -h   Display this help message
    ```
    ```
    ../../script/generate_keys.sh
    ```
    - For AVB-1.0+ (e.g. sargo- Pixel 3a, aliothin/alioth- Mi 11X/Poco F3), generate the keys using the following commands:
    ```
    ../../script/generate_keys.sh -v
    ```
    - For AVB-1.0 (e.g. marlin- Pixel XL), generate the keys using the following commands:
    ```
    ../../out/host/linux-x86/bin/generate_verity_key -convert verity.x509.pem verity_key
    openssl x509 -outform der -in verity.x509.pem -out kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509
    ```
    - Navigate back to the build directory:
    ```
    cd ../../
    ```
4.  Generate a signed build OTA and factory image using the following command:
    ```
    script/release.sh alioth
    ```
5. (Optional) Generate delta packages (Incremental updates) using the following command:
    ```
    bash script/generate_delta.sh alioth \
    out/release-alioth-$OLD_BUILD_NUMBER/lineage_alioth-target_files-$OLD_BUILD_NUMBER.zip \
    out/release-alioth-$NEW_BUILD_NUMBER/lineage_alioth-target_files-$NEW_BUILD_NUMBER.zip
    ```

Note:

- The build out directory is out/release-alioth-$BUILD_NUMBER
- The build out for delta is out/release-alioth-$NEW_BUILD_NUMBER
- Flashing avb_custom_key for AVB-1.0+ (Flash OTA or factory image afterwards)
    ```
    fastboot erase avb_custom_key
    fastboot flash avb_custom_key keys/alioth/avb_pkmd.bin
    ```
- To Lock bootloader  AVB-1.0+
    ```
    fastboot flashing lock
    ```
    To Lock bootloader  AVB-1.0
    ```
    fastboot oem lock
    ```
