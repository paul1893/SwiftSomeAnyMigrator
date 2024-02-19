#!/bin/bash

set -e

GREEN='\033[1;32m'
NC='\033[0m' # No Color

green () {
  printf "${GREEN}${1}${NC}\n"
}

codesign () {
  /usr/bin/codesign --force --options=runtime --timestamp --sign "$SWIFT_SOME_ANY_MIGRATOR_CODE_SIGN" "$1"
}

notarize () {
  xcrun notarytool submit --keychain-profile "SwiftSomeAnyMigratorNotarize" --wait "$1"
}

bin_path=$(make show_bin_path)
rm -rf "$bin_path"
make build_release
rm -rf .release
mkdir .release
cp "$bin_path" .release/
cp LICENSE.md .release/

## Codesign
green "Codesign"
cd .release
mv CommandLineTool migrator
codesign migrator

# Archive
green "Archive"
zip_filename="migrator.zip"
zip "${zip_filename}" migrator LICENSE.md
green "Archive > Codesign"
codesign "${zip_filename}"

echo -e "\n${zip_filename} checksum:"
sha256=$( shasum -a 256 ${zip_filename} | awk '{print $1}' )
echo ${sha256}
open ./

# Notarize
green "Notarize"
notarize "${zip_filename}"