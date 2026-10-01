"""Expose the retained editor solver for an isolated benchmark, never gameplay."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
source=root/'addons/vrm/vrm_secondary.gd'
out=root/'test-results/vrm-optimization';out.mkdir(parents=True,exist_ok=True)
text=source.read_text().replace('class_name VRMSecondary\n','').replace('"./','"res://addons/vrm/').replace('static var springs_enabled:=false','static var springs_enabled:=true')
a=text.index('\tif not Engine.is_editor_hint():',text.index('func _ready()'))
b=text.index('\treset_animation_budget()',a)
text=text[:a]+text[b:]
(out/'scripted_reference.gd').write_text(text)
(out/'scripted-reference-source.json').write_text(json.dumps({'source':str(source.relative_to(root)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'change':'Test-only: remove class registration, rebase preloads, bypass native setup to initialize retained GDScript solver'},indent=2)+'\n')
