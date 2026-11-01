#!/usr/bin/env bash
# يبني مشروع أندرويد كامل من الشيفرة المصدرية ثم ينتج ملف APK
set -euo pipefail
cd "$(dirname "$0")"
rm -rf build_app
flutter create --platforms=android --org com.alalamiya --project-name client_follow build_app
rm -rf build_app/lib build_app/test
cp -r lib build_app/lib
cp pubspec.yaml build_app/pubspec.yaml
cp android_overrides/AndroidManifest.xml build_app/android/app/src/main/AndroidManifest.xml
cp -r android_overrides/res/. build_app/android/app/src/main/res/
python3 patch_gradle.py build_app
cd build_app
flutter pub get
flutter build apk --release
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
