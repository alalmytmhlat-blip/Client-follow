#!/usr/bin/env bash
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

# compileSdk الخاص بالتطبيق لا يغيّر compileSdk المحدد داخل إضافات Flutter.
# نضبط إعدادات Gradle الخاصة بالإضافات بعد تنزيل الاعتماديات.
python3 - <<'PY'
import os, re, sys
cache = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))
roots = [os.path.join(cache, "hosted"), os.path.join(cache, "git")]
patched = []
file_picker_files = []
for root in roots:
    if not os.path.isdir(root):
        continue
    for base, dirs, files in os.walk(root):
        if os.path.basename(base) != "android":
            continue
        for name in ("build.gradle", "build.gradle.kts"):
            path = os.path.join(base, name)
            if not os.path.isfile(path):
                continue
            with open(path, encoding="utf-8") as f:
                source = f.read()
            updated = re.sub(
                r"(?m)^(\s*compileSdk(?:Version)?\s*(?:=\s*)?).*$",
                lambda m: m.group(1) + "36",
                source)
            if updated != source:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(updated)
                patched.append(path)
            normalized = path.replace("\\", "/")
            if "file_picker-" in normalized:
                file_picker_files.append(path)
print("Patched Android plugin Gradle files:", len(patched))
for path in patched:
    print(path)
if not file_picker_files:
    sys.exit("ERROR: file_picker Android Gradle file not found")
for path in file_picker_files:
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if not re.search(r"(?m)^\s*compileSdk(?:Version)?\s*(?:=\s*)?36\s*$", text):
        sys.exit("ERROR: file_picker compileSdk is not API 36: " + path)
print("Verified file_picker compileSdk 36")
PY

flutter build apk --release
test -s build/app/outputs/flutter-apk/app-release.apk
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
