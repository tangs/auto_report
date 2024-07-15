#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

buildPath='release/android'
destPath='/Volumes/tangsong/auto_report/android'

rm -rf "$destPath/kbz_reporter_v$version.apk"
rm -rf "$destPath/wave_reporter_v$version.apk"

cp -rf "$buildPath/kbz_reporter_v$version.apk" "$destPath/"
cp -rf "$buildPath/wave_reporter_v$version.apk" "$destPath/"