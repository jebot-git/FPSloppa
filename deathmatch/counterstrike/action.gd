extends Node
## Presentation only: accepted shots and replicated reload state drive the moving
## action. The shared combat code remains the sole source of ammunition/damage.
var slot:=0
var parts: Dictionary={}
var rest: Dictionary={}
var elapsed:=10.0
var duration:=.1
var empty:=false
var reload_ms:=0
var life:=-1
var physical:=false
var manual_stroke:=0.0
var cover:=0.0
var chambered:=true
var rack_held:=false
var slide_locked:=false
func setup(model: Node3D,index: int):
	name="ChamberAction";slot=index
	for key in ["Slide","Bolt","Pump","ChargingHandle","Magazine","FeedCover"]:
		var part:=model.find_child(key,true,false) as Node3D
		if part:parts[key]=part;rest[key]=part.transform
	set_process(false)
func shot():
	if slot==0:return
	if physical and slot in [3,9]:return
	elapsed=0;duration=.70 if slot==3 else 1.35 if slot==9 else .12
	set_process(true);pose(.12)
func sync(row: Array):
	if row.size() not in [5,9]:return
	if life!=row[0]:life=row[0];elapsed=10;empty=false;reload_ms=0
	empty=row[2]==0;reload_ms=row[3]
	physical=row.size()==9 and row[5]&1!=0
	chambered=not physical or row[5]&4!=0
	rack_held=physical and row[5]&8!=0
	slide_locked=physical and row[5]&32!=0
	manual_stroke=float(row[6])/100 if physical else 0.0;cover=float(row[7])/100 if physical else 0.0
	if parts.has("Magazine"):parts.Magazine.visible=not physical or row[5]&2!=0
	if physical and slot in [3,9]:elapsed=duration;set_process(false)
	if elapsed>=duration:pose(1.0)
func pose(t: float):
	for key in parts:parts[key].transform=rest[key]
	var stroke:=0.0 if t>=1 else sin(clampf(t,0,1)*PI)
	if physical and slot in [3,9]:stroke=0.0
	if reload_ms>0:
		# Chamber near the end of a magazine reload. Tube-fed shotguns retain
		# their normal shot/pump cycle rather than pumping after every shell.
		if slot not in [3,4]:stroke=maxf(stroke,sin(clampf((400-reload_ms)/400.0,0,1)*PI))
	if physical:stroke=maxf(stroke,manual_stroke)
	if parts.has("Slide"):parts.Slide.position.z+=.045*maxf(stroke,1.0 if (slide_locked if physical else empty) else 0.0)
	if parts.has("Pump"):parts.Pump.position.z+=.105*stroke
	if parts.has("Bolt"):
		if slot==9:
			if physical:
				parts.Bolt.rotation.z-=manual_stroke*PI/3;parts.Bolt.position.z+=.10*manual_stroke
				return
			var cycle: float=clampf(t,0,1)
			var lift: float=smoothstep(.10,.25,cycle)*(1-smoothstep(.82,.98,cycle))
			var pull: float=smoothstep(.25,.43,cycle)*(1-smoothstep(.60,.82,cycle))
			if reload_ms>0:lift=stroke;pull=stroke
			parts.Bolt.rotation.z-=lift*PI/3;parts.Bolt.position.z+=.10*pull
		else:parts.Bolt.position.z+=.028*stroke
	# M4/MP5/M249/P90 charging handles stay still during automatic fire.
	if parts.has("ChargingHandle") and reload_ms>0:parts.ChargingHandle.position.z+=.045*stroke
	if parts.has("ChargingHandle") and physical:parts.ChargingHandle.position.z+=.045*manual_stroke
	if parts.has("FeedCover"):parts.FeedCover.rotation.x=-cover*deg_to_rad(80)
func _process(delta: float):
	elapsed=minf(duration,elapsed+delta);pose(elapsed/duration)
	if elapsed>=duration:set_process(false)
