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
gp = os.path.join(d, 'android/gradle.properties')
props = open(gp, encoding='utf-8').read() if os.path.exists(gp) else ''
if 'kotlin.jvm.target.validation.mode' not in props:
    props += '\nkotlin.jvm.target.validation.mode=IGNORE\n'
open(gp, 'w', encoding='utf-8').write(props)
print('gradle patched')
