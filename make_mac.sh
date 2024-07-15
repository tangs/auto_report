#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

buildPath='release/macos'
mkdir -p $buildPath

sh setup_kbz.sh
# flutter clean
flutter build macos --release

rm -rf "$buildPath/kbz_reporter_v$version.app"
rm -rf "$buildPath/auto_report.app"
cp -rf build/macos/Build/Products/Release/auto_report.app "$buildPath"
mv "$buildPath/auto_report.app" "$buildPath/kbz_reporter_v$version.app"


sh setup_wave.sh
# flutter clean
flutter build macos --release

rm -rf "$buildPath/wave_reporter_v$version.app"
rm -rf "$buildPath/auto_report.app"
cp -rf build/macos/Build/Products/Release/auto_report.app "$buildPath"
mv "$buildPath/auto_report.app" "$buildPath/wave_reporter_v$version.app"