#!/usr/bin/env sh

sed -i "" "s/static BankType bankType = BankType.*;/static BankType bankType = BankType.wave;/g" lib/config/global_config.dart
sed -i '' 's|assets/ic_.*logo.png|assets/ic_wave_logo.png|g' pubspec.yaml
sed -i '' 's|applicationId = "com.example.auto_report.*"|applicationId = "com.example.auto_report.wave"|g' android/app/build.gradle
sed -i '' 's|android:label=".*report"|android:label="wave report"|g' android/app/src/main/AndroidManifest.xml

dart run icons_launcher:create
