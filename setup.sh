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

# بعض إضافات Flutter (ومنها file_picker) تحدد compileSdk داخل ملفها
# بشكل مستقل عن compileSdk الخاص بالتطبيق؛ نرفعها إلى 36 بعد تنزيل الاعتماديات.
python3 - <<'PY'
import os, re
cache = os.environ.get("PUB_CACHE", os.path.expanduser("~/.pub-cache"))
hosted = os.path.join(cache, "hosted")
patched = []
for base, dirs, files in os.walk(hosted):
    if os.path.basename(base) != "android":
        continue
    for name in ("build.gradle", "build.gradle.kts"):
        path = os.path.join(base, name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            source = f.read()
        updated = re.sub(r"(?m)^(\\s*compileSdkVersion\\s+)34(\\s*)$", r"\\g<1>36\\g<2>", source)
        updated = re.sub(r"(?m)^(\\s*compileSdk\\s*=\\s*)34(\\s*)$", r"\\g<1>36\\g<2>", updated)
        updated = re.sub(r"(?m)^(\\s*compileSdk\\s+)34(\\s*)$", r"\\g<1>36\\g<2>", updated)
        if updated != source:
            with open(path, "w", encoding="utf-8") as f:
                f.write(updated)
            patched.append(path)
print("Plugin compileSdk patched:", len(patched))
for path in patched:
    print(path)
PY

flutter build apk --release
echo "APK: $(pwd)/build/app/outputs/flutter-apk/app-release.apk"
