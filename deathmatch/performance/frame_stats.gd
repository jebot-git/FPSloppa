extends Node
## Opt-in real-device frame telemetry: --frame-stats. Compositor timing still required.
var elapsed:=0.0
var warmup:=5.0
var frames: Array[float]=[]
func _process(delta: float) -> void:
	if warmup>0: warmup-=delta;return
	frames.append(delta*1000.0);elapsed+=delta
	if elapsed<10: return
	frames.sort()
	var report:={"frames":frames.size(),"frame_ms_p50":frames[frames.size()/2],"frame_ms_p95":frames[mini(frames.size()-1,int(frames.size()*.95))],"target_ms":1000.0/72,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"xr":get_viewport().use_xr}
	print("FRAME_STATS ",JSON.stringify(report))
	frames.clear();elapsed=0
