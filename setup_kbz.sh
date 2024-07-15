#!/usr/bin/env sh

sed -i "" "s/static BankType bankType = BankType.*;/static BankType bankType = BankType.kbz;/g" lib/config/global_config.dart
sed -i '' 's|assets/ic_.*logo.png|assets/ic_kbz_logo.png|g' pubspec.yaml
sed -i '' 's|applicationId = "com.example.auto_report.*"|applicationId = "com.example.auto_report.kbz"|g' android/app/build.gradle
sed -i '' 's|android:label=".*report.*"|android:label="kbz report"|g' android/app/src/main/AndroidManifest.xml

flutter pub get
dart run icons_launcher:create
