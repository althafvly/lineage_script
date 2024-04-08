## Getting Started

1. Clone the repository using the following command:
   ```
   git clone https://github.com/althafvly/lineage_script -b master script
   ```
2. For signed builds, follow these steps:

   - Set up the environment by running the following command:

   ```
   . build/envsetup.sh
   ```

   - Choose the target device using the following command and selecting the appropriate option:

   ```
   lunch lineage_alioth-userdebug
   ```

3. Generate the target files package, otatools package using the following command:
   ```
   make target-files-package otatools
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
   bash script/generate_keys.sh
   ```
5. Generate a signed build OTA and factory image using the following command:
   ```
   script/release.sh alioth
   ```

5. (Optional) Generate delta packages (Incremental updates) using the following command:

   ```
   script/generate_delta.sh alioth \
   out/target/product/alioth/lineage_alioth-target_files-$OLD_BUILD_DATE.zip \
   out/target/product/alioth/lineage_alioth-target_files-$NEW_BUILD_DATE.zip \
   generated_output.zip
   ```

Note:

- The build should be in this location.
  - out/target/product/alioth
- Target file should be in this location after build.
  - out/target/product/alioth/lineage_alioth-target_files-$BUILD_DATE.zip
