# متابع العملاء (Client Follow)

تطبيق أندرويد (Flutter) لإدارة العملاء ومواعيد المتابعة، يعمل بدون إنترنت.

## بناء ملف APK

### الطريقة 1: على جهازك (يحتاج Flutter SDK + Android SDK)
    bash setup.sh
الناتج: build_app/build/app/outputs/flutter-apk/app-release.apk

### الطريقة 2: سحابيًا بدون تثبيت شيء (GitHub Actions)
1. أنشئ مستودعًا جديدًا على GitHub وارفع محتويات هذا المجلد.
2. افتح تبويب Actions ← Build APK ← Run workflow.
3. بعد دقائق نزّل الملف client-follow-apk من قسم Artifacts.

## بنية المشروع
- lib/data.dart — قاعدة SQLite والنماذج والنسخ الاحتياطي
- lib/notifications.dart — جدولة التنبيهات المحلية
- lib/ui.dart — جميع الشاشات
- android_overrides/ — AndroidManifest (أذونات + مستقبلات التنبيه)
- patch_gradle.py — تفعيل desugaring المطلوب للتنبيهات
- android_overrides/res/ — أيقونة التطبيق (قابلة للتكيّف) وأيقونة الإشعار
- tool/make_icons.py — يعيد توليد الأيقونات (python3 tool/make_icons.py، يحتاج Pillow)

## ملاحظات
- رمز الدولة الافتراضي لواتساب 967 (يمكن تغييره من الإعدادات).
- لتطوير التطبيق لاحقًا عدّل ملفات lib ثم أعد تشغيل setup.sh.
