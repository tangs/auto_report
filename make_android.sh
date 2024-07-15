#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

buildPath='release/android'
mkdir -p $buildPath

sh setup_kbz.sh
flutter build apk --release

rm -rf "$buildPath/kbz_reporter_v$version.apk"
cp -rf build/app/outputs/flutter-apk/app-release.apk "$buildPath/kbz_reporter_v$version.apk"

sh setup_wave.sh
flutter build apk --release

rm -rf "$buildPath/wave_reporter_v$version.apk"
cp -rf build/app/outputs/flutter-apk/app-release.apk "$buildPath/wave_reporter_v$version.apk"

