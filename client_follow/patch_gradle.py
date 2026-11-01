import os, re, sys
d = sys.argv[1]
kts = os.path.join(d, 'android/app/build.gradle.kts')
grv = os.path.join(d, 'android/app/build.gradle')
if os.path.exists(kts):
    s = open(kts, encoding='utf-8').read()
    if 'isCoreLibraryDesugaringEnabled' not in s:
        s = s.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    open(kts, 'w', encoding='utf-8').write(s)
elif os.path.exists(grv):
    s = open(grv, encoding='utf-8').read()
    if 'coreLibraryDesugaringEnabled' not in s:
        s = s.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true', 1)
        s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    open(grv, 'w', encoding='utf-8').write(s)
else:
    sys.exit('build.gradle not found')
print('gradle patched')
