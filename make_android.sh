#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

flutter clean
flutter build apk --release

rm -rf "/Volumes/tangsong/auto_report/android/auto_report_v$version.apk"
cp -rf build/app/outputs/flutter-apk/app-release.apk "/Volumes/tangsong/auto_report/android/auto_report_v$version.apk"
