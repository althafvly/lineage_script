#!/bin/bash

set -o errexit -o nounset -o pipefail

# set the umask to 022 for default file permissions
umask 022
# create an alias for the "which" command to use the built-in "command" command
alias which='command -v'
# load environment setup script to set up build environment
source build/envsetup.sh

# set the language to US English with UTF-8 encoding
export LANG=en_US.UTF-8
# set a Java VM option to disable performance data
export _JAVA_OPTIONS=-XX:-UsePerfData
# set the build date and time to the contents of the "out/build_date.txt" file or the current Unix timestamp in UTC format
export BUILD_DATETIME=$(cat out/build_date.txt 2>/dev/null || date -u +%s)
# print the build date and time to the console
echo "BUILD_DATETIME=$BUILD_DATETIME"
# set the build number to the contents of the "out/soong/build_number.txt" file or the date and time corresponding to the Unix timestamp in the specified format
export BUILD_NUMBER=$(cat out/soong/build_number.txt 2>/dev/null || date -u -d @$BUILD_DATETIME +%Y%m%d%H)
# print the build number to the console
echo "BUILD_NUMBER=$BUILD_NUMBER"
# set a flag to indicate that the build number should be displayed
export DISPLAY_BUILD_NUMBER=true
# set the build username and hostname to "lineageos"
export BUILD_USERNAME=lineageos
export BUILD_HOSTNAME=lineageos
