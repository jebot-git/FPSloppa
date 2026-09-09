"""Install Android packages required by the actual Godot 4.7.2 template."""
from pathlib import Path
import subprocess,os
sdk=Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home()/'Android/Sdk')))
jdk=Path(os.environ.get('JAVA_HOME', str(Path.home()/'.local/share/entryway-toolchains/jdk-17.0.20.1+1')))
env=os.environ.copy();env['JAVA_HOME']=str(jdk)
env['PATH']=str(jdk/'bin')+os.pathsep+env['PATH']
packages=['platform-tools','platforms;android-36','build-tools;36.1.0','ndk;29.0.14206865','cmake;3.10.2.4988404']
log=Path(__file__).resolve().parents[1]/'test-results/android-dependencies.log'
log.parent.mkdir(exist_ok=True)
with log.open('w') as output:
 result=subprocess.run([str(sdk/'cmdline-tools/latest/bin/sdkmanager'),'--sdk_root='+str(sdk),*packages],input='y\n'*100,text=True,stdout=output,stderr=subprocess.STDOUT,env=env)
print('ANDROID_DEPENDENCIES',result.returncode,'log',log)
raise SystemExit(result.returncode)
