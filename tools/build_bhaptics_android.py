"""Package the native ARM64 library and its Godot Android/JNI bootstrap as an AAR.

Compiles Java directly because this plugin has no Android resources. Gradle consumes
the resulting standard AAR when exporting the game. Sources come from locked crates.
"""
from pathlib import Path
import argparse, json, os, subprocess, tempfile, zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/bhaptics_native'

def build(sdk: Path, jdk: Path, godot_aar: Path):
    library = ADDON / 'bin/libfpsloppa_bhaptics_native.android.so'
    if not library.exists(): raise SystemExit('Build aarch64-linux-android first.')
    metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--offline', '--locked', '--format-version', '1', '--manifest-path', str(ADDON/'native/Cargo.toml')], text=True))
    packages = {p['name']: Path(p['manifest_path']).parent for p in metadata['packages']}
    source_roots = [packages['btleplug']/'src/droidplug/java/src/main/java', packages['jni-utils']/'java/src/main/java']
    sources = [str(p) for folder in source_roots for p in sorted(folder.rglob('*.java'))]
    sources.append(str(ADDON/'android/BhapticsAndroid.java'))
    with tempfile.TemporaryDirectory(prefix='bhaptics-aar-') as temp:
        work = Path(temp); classes = work/'classes'; classes.mkdir()
        with zipfile.ZipFile(godot_aar) as z: z.extract('classes.jar', work)
        classpath = os.pathsep.join([str(sdk/'platforms/android-36/android.jar'), str(work/'classes.jar')])
        subprocess.run([str(jdk/'bin/javac'), '--release', '8', '-classpath', classpath, '-d', str(classes), *sources], check=True)
        jar = work/'compiled.jar'
        with zipfile.ZipFile(jar, 'w', zipfile.ZIP_DEFLATED) as z:
            for path in sorted(classes.rglob('*.class')): z.write(path, path.relative_to(classes).as_posix())
        target = ADDON/'bin/fpsloppa-bhaptics-android.aar'
        staged = target.with_suffix('.aar.tmp')
        with zipfile.ZipFile(staged, 'w', zipfile.ZIP_DEFLATED, strict_timestamps=False) as z:
            z.write(jar, 'classes.jar')
            z.write(ADDON/'android/AndroidManifest.xml', 'AndroidManifest.xml')
            z.write(ADDON/'android/proguard-rules.pro', 'proguard.txt')
            # android_aar_plugin descriptors are skipped by Godot's PCK exporter;
            # the Java plugin supplies this path relative to the AAR assets root.
            z.write(ADDON/'bhaptics.gdextension.in', 'assets/addons/bhaptics_native/bhaptics.gdextension')
            z.writestr('R.txt', '')
            z.write(library, 'jni/arm64-v8a/'+library.name, compress_type=zipfile.ZIP_STORED)
            for name in ['btleplug', 'jni-utils']:
                licence = next(p for p in packages[name].glob('LICENSE*') if p.is_file())
                z.write(licence, 'META-INF/licenses/'+name+'.txt')
        os.replace(staged, target)
        print(f'Built {target} ({target.stat().st_size} bytes)')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', type=Path, default=Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home()/'Android/Sdk'))))
    parser.add_argument('--jdk', type=Path, default=Path(os.environ.get('JAVA_HOME', str(Path.home()/'.local/share/entryway-toolchains/jdk-17.0.20.1+1'))))
    parser.add_argument('--godot-aar', type=Path, default=ROOT/'android/build/libs/release/godot-lib.template_release.aar')
    args = parser.parse_args(); build(args.sdk, args.jdk, args.godot_aar)
