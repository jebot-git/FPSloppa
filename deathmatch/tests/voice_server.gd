extends SceneTree
const Codec=preload("res://deathmatch/voice/codec.gd")
const Config=preload("res://deathmatch/server/config.gd")
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run() -> void:
	var samples:=PackedFloat32Array()
	for i in range(Codec.FRAMES): samples.append(sin(i*TAU*440/Codec.RATE)*.4)
	var data:=Codec.encode(samples)
	var output:=Codec.decode(data)
	var error:=0.0
	for i in range(output.size()): error+=pow(output[i].x-samples[i],2)
	check(data.size()==164 and output.size()==320 and sqrt(error/320)<.025,"Independent voice block decodes with bounded error")
	data[2]=255
	check(Codec.decode(data).is_empty(),"Malformed codec state rejected")
	var parsed:=Config.parse('sets sv_hostname "My // arena" // comment\nset net_port 28888\nset sv_voice 0\nmap lqdm7')
	check(parsed.has("values") and parsed.values.sv_hostname=="My // arena" and parsed.values.net_port==28888 and parsed.values.map=="lqdm7" and parsed.values.sv_voice==0,"Q3-style config quotes, comments and settings")
	for source in ['exec "shell.cfg"','set net_port 1','set sv_maxclients 999','map "broken','set net_port 7777; quit','set typo 4']:
		check(Config.parse(source).has("error"),"Config rejects invalid command: "+source)
	var g=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(g)
	g.active=true
	g.players[2]=g._new_state("Speaker",2)
	data=Codec.encode(samples)
	check(g.voice.mode==0 and g.voice.mic==null,"Microphone defaults to off")
	check(g.voice.accept_sender(2,1,data),"Joined speaker accepted")
	check(not g.voice.accept_sender(3,1,data),"Unjoined speaker rejected")
	check(not g.voice.accept_sender(2,1,data),"Replayed voice sequence rejected")
	check(not g.voice.accept_sender(2,2,PackedByteArray([1,2,3])),"Oversized/invalid block length rejected")
	for i in range(2,9): g.voice.accept_sender(2,i,data)
	check(not g.voice.accept_sender(2,9,data),"Voice flood budget enforced")
	g.clock+=.1
	check(g.voice.accept_sender(2,10,data),"Voice budget recovers over time")
	g.voice_enabled=false
	check(not g.voice.accept_sender(2,11,data),"Host voice policy enforced")
	var rig=load("res://deathmatch/vr/rig.gd").new()
	check(rig.smooth_turn,"Smooth turning defaults on")
	rig.free()
	g.active=false
	print("VOICE_SERVER_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
