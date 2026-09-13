"""Export a tiny native-plugin smoke app, without loading FPSloppa's maps.

Android app is a separate package. It tests JNI initialization and a bounded scan
when Bluetooth permissions are granted. It never connects or actuates a vest.
"""
from pathlib import Path
import argparse, os, shutil, subprocess, zipfile
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('platform', choices=['Android', 'Windows'])
parser.add_argument('--work', type=Path, default=ROOT/'test-results/bhaptics-build-smoke')
args = parser.parse_args()
p = args.work.resolve()/args.platform.lower(); p.mkdir(parents=True, exist_ok=True)
(p/'.godot').mkdir(exist_ok=True)
# Load at engine startup. The local Godot build aborts on first-import teardown
# when this Rust extension is discovered and loaded during the editor scan.
(p/'.godot/extension_list.cfg').write_text('res://addons/bhaptics_native/bhaptics.gdextension\n')
addon = p/'addons/bhaptics_native'; (addon/'bin').mkdir(parents=True, exist_ok=True)
for file in (ROOT/'addons/bhaptics_native/bin').iterdir():
    if file.is_file(): shutil.copy2(file, addon/'bin'/file.name)
for file in ['bhaptics.gdextension', 'android_export.gd']:
    shutil.copy2(ROOT/'addons/bhaptics_native'/file, addon/file)
(addon/'plugin.cfg').write_text('[plugin]\nname="Bluetooth smoke export"\ndescription=""\nauthor="FPSloppa"\nversion="1"\nscript="plugin.gd"\n')
(addon/'plugin.gd').write_text('''@tool
extends EditorPlugin
var exporter: EditorExportPlugin
func _enter_tree() -> void:
 exporter=preload("res://addons/bhaptics_native/android_export.gd").new()
 add_export_plugin(exporter)
func _exit_tree() -> void:remove_export_plugin(exporter)
''')
(p/'project.godot').write_text('''config_version=5
[application]
config/name="bHaptics native smoke test"
config/icon="res://icon.png"
run/main_scene="res://smoke.tscn"
[rendering]
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
rendering_device/fallback_to_opengl3=false
textures/vram_compression/import_etc2_astc=true
[editor_plugins]
enabled=PackedStringArray("res://addons/bhaptics_native/plugin.cfg")
''')
shutil.copy2(ROOT/'deathmatch/icon-final.png', p/'icon.png')
(p/'smoke.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://smoke.gd" id="1"]\n[node name="Smoke" type="Node"]\nscript=ExtResource("1")\n')
(p/'smoke.gd').write_text('''extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 var loaded = ClassDB.class_exists("FpsloppaBhapticsBle")
 print("BHAPTICS_SMOKE_CLASS ", loaded)
 if not loaded:get_tree().quit(1);return
 var bridge = ClassDB.instantiate("FpsloppaBhapticsBle")
 var ok = not bridge.is_running() and not bridge.device_connected()
 ok = ok and not bridge.submit_frame(PackedByteArray([1]), .25)
 var frame = PackedByteArray();frame.resize(40);frame.fill(15)
 ok = ok and not bridge.submit_levels(frame, .25)
 if OS.get_name()=="Android":
  var registered = Engine.has_singleton("FpsloppaBhapticsAndroid")
  print("BHAPTICS_SMOKE_JAVA ",registered)
  if not registered:get_tree().quit(1);return
  var helper = Engine.get_singleton("FpsloppaBhapticsAndroid")
  var ready = helper.prepare()
  print("BHAPTICS_SMOKE_JNI ",ready," ",helper.status_text())
  ok = ok and ready
  if ready:
   bridge.scan()
   await get_tree().create_timer(10).timeout
   print("BHAPTICS_SMOKE_SCAN ",bridge.status_text()," ",bridge.devices_json())
   ok = ok and (bridge.status_text().begins_with("Scan complete.") or bridge.status_text().begins_with("No supported vest found."))
 bridge.stop();bridge.close()
 var start = Time.get_ticks_msec()
 while bridge.is_running() and Time.get_ticks_msec()-start<5000:await get_tree().process_frame
 ok = ok and not bridge.is_running() and not bridge.device_connected()
 bridge=null
 print("BHAPTICS_SMOKE_PASS ",ok)
 get_tree().quit(0 if ok else 1)
''')
android = args.platform=='Android'
(p/'output').mkdir(exist_ok=True)
out=p/'output'/('smoke.apk' if android else 'smoke.exe')
options='''gradle_build/use_gradle_build=true
gradle_build/min_sdk="26"
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
package/unique_name="org.fpsloppa.bhaptics.smoke"
package/name="bHaptics native smoke test"
package/signed=true
xr_features/xr_mode=0
''' if android else 'binary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n'
(p/'export_presets.cfg').write_text('[preset.0]\nname="Smoke"\nplatform="'+('Android' if android else 'Windows Desktop')+'"\nrunnable=false\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="output/*,*.log"\n[preset.0.options]\n'+options)
if android and not (p/'android/build/gradlew').exists():
    template=Path.home()/'.local/share/godot/export_templates/4.7.2.stable/android_source.zip'
    with zipfile.ZipFile(template) as z:z.extractall(p/'android/build')
    (p/'android/.build_version').write_text('4.7.2.stable')
    (p/'android/.gdignore').touch()
    (p/'android/build/gradlew').chmod(0o755)
for flags,name in [(['--editor','--import'],'import'),(['--export-debug' if android else '--export-release','Smoke',str(out)],'export')]:
    with (p/(name+'.log')).open('w') as log:
        subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(p),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
print(out)
