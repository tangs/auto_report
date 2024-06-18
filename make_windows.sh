#!/usr/bin/env sh

version=`cat pubspec.yaml | grep 'version:' | awk '{print $2}' | sed 's/+/_/'`
echo $version

flutter build windows --release

rm -rf "//192.168.1.248/tangsong/auto_report/windows/auto_report_v$version.exe"
rm -rf "//192.168.1.248/tangsong/auto_report/windows/data"
rm -rf "//192.168.1.248/tangsong/auto_report/windows/flutter_windows"
cp -rf build/windows/x64/runner/Release/auto_report.exe "//192.168.1.248/tangsong/auto_report/windows/auto_report_v$version.exe"
cp -rf build/windows/x64/runner/Release/flutter_windows.dll "//192.168.1.248/tangsong/auto_report/windows/"
cp -rf build/windows/x64/runner/Release/data "//192.168.1.248/tangsong/auto_report/windows/data"
