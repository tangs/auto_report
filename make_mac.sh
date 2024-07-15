#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

sh setup_kbz.sh
flutter clean
flutter build macos --release

rm -rf "/Volumes/tangsong/auto_report/macos/kbz_reporter_v$version.app"
cp -rf build/macos/Build/Products/Release/auto_report.app "/Volumes/tangsong/auto_report/macos/kbz_reporter_v$version.app"


sh setup_wave.sh
flutter clean
flutter build macos --release

rm -rf "/Volumes/tangsong/auto_report/macos/wave_reporter_v$version.app"
cp -rf build/macos/Build/Products/Release/auto_report.app "/Volumes/tangsong/auto_report/macos/wave_reporter_v$version.app"