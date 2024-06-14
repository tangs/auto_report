#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

flutter build apk --release
cp -rf build/macos/Build/Products/Release/auto_report.app "/Volumes/tangsong/auto_report/macos/auto_report_v$version.app"
