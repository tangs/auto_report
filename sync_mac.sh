#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

buildPath='release/macos'
destPath='/Volumes/tangsong/auto_report/macos'

rm -rf "$destPath/kbz_reporter_v$version.app"
rm -rf "$destPath/wave_reporter_v$version.app"

cp -rf "$buildPath/kbz_reporter_v$version.app" "$destPath/"
cp -rf "$buildPath/wave_reporter_v$version.app" "$destPath/"