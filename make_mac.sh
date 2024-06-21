#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

# flutter clean
# flutter build macos --release

rm -rf "/Volumes/tangsong/auto_report/macos/auto_report_v$version.app"
cp -rf build/macos/Build/Products/Release/auto_report.app "/Volumes/tangsong/auto_report/macos/auto_report_v$version.app"
