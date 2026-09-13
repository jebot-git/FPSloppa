"""Install/run the separate Quest/Android plugin smoke app; never actuates a vest."""
from pathlib import Path
import argparse, os, subprocess, time
ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--serial', required=True)
parser.add_argument('--timeout', type=float, default=45)
args = parser.parse_args()
work=ROOT/'test-results/bhaptics-build-smoke/android'
adb=['adb','-s',args.serial]
package='org.fpsloppa.bhaptics.smoke'
subprocess.run([*adb,'install','-r','-g',str(work/'output/smoke.apk')],check=True)
subprocess.run([*adb,'shell','am','force-stop',package],check=True)
# Follow only Godot/error tags; retain this app's PID below before writing the report.
with (work/'capture.log').open('w') as capture:
    process=subprocess.Popen([*adb,'logcat','-T','1','-v','brief','Godot:V','godot:V','AndroidRuntime:E','*:S'],stdout=capture,stderr=subprocess.STDOUT)
    try:
        subprocess.run([*adb,'shell','am','start','-W','-n',package+'/com.godot.game.GodotAppLauncher'],check=True)
        pid=subprocess.check_output([*adb,'shell','pidof',package],text=True).strip()
        deadline=time.monotonic()+args.timeout
        result=''
        while time.monotonic()<deadline:
            lines=(work/'capture.log').read_text().splitlines()
            own=[line for line in lines if '('+pid+')' in line or '('+pid.rjust(5)+')' in line]
            result='\n'.join(own)+'\n'
            if 'BHAPTICS_SMOKE_PASS ' in result:break
            time.sleep(.25)
        (work/'runtime.log').write_text(result)
        print('\n'.join(line for line in result.splitlines() if 'BHAPTICS_' in line or 'ERROR:' in line))
        if 'BHAPTICS_SMOKE_PASS true' not in result:
            subprocess.run([*adb,'shell','am','force-stop',package],check=True)
            raise SystemExit('Android smoke test did not pass; see '+str(work/'runtime.log'))
    finally:
        process.terminate()
        try:process.wait(timeout=5)
        except subprocess.TimeoutExpired:process.kill();process.wait()
