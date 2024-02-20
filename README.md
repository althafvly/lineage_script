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
   lunch lineage_alioth-userdebug
   ```

3. Generate the target files package, otatools package using the following command:
   ```
   make target-files-package otatools generate_verity_key
   ```

4. Generate keys (Skip this step if you have already generated keys. Make sure they are in the keys directory).

   - Create a new folder for the keys:

   ```
   mkdir -p ~/.android-certs/alioth
   cd ~/.android-certs/alioth
   ```

   - Run the generate_keys.sh script to generate the keys:

   ```
   Usage: generate_keys.sh [-a] [-n] [-v] [-h]
     -a   Generate apex certs
     -n   Do not prompt for password
     -v   Generate AVB certificate
     -h   Display this help message
   ```

   ```
   $LOS_ROOT/script/generate_keys.sh
   ```

   - For AVB-1.0+ (e.g. sargo- Pixel 3a, aliothin/alioth- Mi 11X/Poco F3), generate the keys using the following commands, Make sure that AVB is not disabled:

   ```
   $LOS_ROOT/script/generate_keys.sh -v
   ```

   - Navigate back to the build directory:

   ```
   cd $LOS_ROOT
   ```

   - For AVB-1.0 (e.g. marlin- Pixel XL), generate the keys using the following commands, location in kernel is might differ for devices:

   ```
   make generate_verity_key
   generate_verity_key -convert ~/.android-certs/marlin/verity.x509.pem ~/.android-certs/marlin/verity_key
   openssl x509 -outform der -in ~/.android-certs/marlin/verity.x509.pem -out $LOS_ROOT/kernel/google/marlin/verifiedboot_marlin_relkeys.der.x509
   ```
5. Generate a signed build OTA and factory image using the following command:
   ```
   $LOS_ROOT/script/release.sh alioth
   ```

5. (Optional) Generate delta packages (Incremental updates) using the following command:

   ```
   $LOS_ROOT/script/generate_delta.sh alioth \
   out/target/product/alioth/lineage_alioth-target_files-$OLD_BUILD_NUMBER.zip \
   out/target/product/alioth/lineage_alioth-target_files-$NEW_BUILD_NUMBER.zip
   ```

Note:

- The build should be in any of these location after build.
  - out/target/product/alioth
- Target file should be in any of these location after build.
  - out/target/product/alioth/lineage_alioth-target_files-$BUILD_NUMBER.zip
- Flashing avb_custom_key for AVB-1.0+ (Flash OTA or factory image afterwards, only if device supports)
  ```
  fastboot erase avb_custom_key
  fastboot flash avb_custom_key ~/.android-certs/alioth/avb_pkmd.bin
  ```
- To lock bootloader AVB-1.0+
  ```
  fastboot flashing lock
  ```
  To lock bootloader AVB-1.0
  ```
  fastboot oem lock
  ```
