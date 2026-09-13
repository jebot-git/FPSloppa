extends SceneTree
const Output=preload("res://deathmatch/haptics/osc.gd")
const Service=preload("res://deathmatch/haptics/service.gd")
const Preferences=preload("res://deathmatch/haptics/preferences.gd")
var failures: Array=[]
var packets:=0
class Fixture extends Node:
	var headless:=false
	var dedicated:=false
	var quitting:=false
	var active:=true
	var menu_open:=false
	var map_loading:=false
	var demos:={"playing":false}
	var players:={1:{"spectator":false,"dead":false},2:{"spectator":false,"dead":false}}
	var local_yaw:=0.0
	var xr_rig=null
	var fighters: Dictionary={}
	var armory=preload("res://deathmatch/experimental/weapon_rules.gd").new()
	func _init():armory.select("doom")
	var haptics: Node
	func is_vr() -> bool:return false
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func drain(receiver: PacketPeerUDP) -> Dictionary:
	var result: Dictionary={}
	while receiver.get_available_packet_count()>0:
		var packet:=receiver.get_packet();packets+=1
		if not (packet.size()<=1200 and packet.slice(0,16)==PackedByteArray([35,98,117,110,100,108,101,0,0,0,0,0,0,0,0,1])):check(false,"OSC bundle fits MTU and has immediate timetag")
		var stream:=StreamPeerBuffer.new();stream.big_endian=true;stream.data_array=packet;stream.seek(16)
		while stream.get_available_bytes()>=4:
			var size:=stream.get_u32()
			if size>stream.get_available_bytes():check(false,"Truncated OSC packet");return result
			var data: PackedByteArray=stream.get_data(size)[1]
			var end:=data.find(0)
			var path:=data.slice(0,end).get_string_from_ascii()
			var cursor: int=(end+4)&~3
			var tag:=data.slice(cursor).get_string_from_ascii()
			if not (tag in [",T",",F"] and data.size()==cursor+4):check(false,"OSC boolean has no payload and uses four-byte padding")
			result[path]=tag==",T"
	return result
func any_on(values: Dictionary) -> bool:return values.values().has(true)
func run() -> void:
	var path:="/tmp/fpsloppa-bhaptics-test.cfg"
	var cfg:=ConfigFile.new();cfg.set_value("profile","name","Preserved");cfg.set_value("presentation","master",.4);cfg.save(path)
	check(not Preferences.read_settings(path).enabled,"Haptics is off for existing profiles")
	check(not Preferences.sanitize({"enabled":"true"}).enabled,"Malformed enabled flag cannot activate output")
	for port_value in [NAN,INF,-1,65536,"9001",true]:
		check(not Preferences.sanitize({"enabled":true,"backend":"osc","port":port_value}).enabled,"Malformed port disables output")
	check(not Preferences.sanitize({"enabled":true,"backend":"osc","host":"receiver.example"}).enabled,"Hostnames cannot block the render thread on DNS")
	var config:={"enabled":true,"backend":"osc","host":"127.0.0.1","port":9001,"pickups":true}
	check(Preferences.save_settings(config,path)==OK and Preferences.read_settings(path).pickups,"Haptics preferences survive restart")
	cfg.load(path);check(cfg.get_value("profile","name")=="Preserved" and cfg.get_value("presentation","master")==.4,"Saving haptics preserves other preferences")
	check(Output.message(0,true).get_string_from_ascii().begins_with("/avatar/parameters/bOSC/v2/VestFront/0/others"),"Current vendor OSC v2 address uses zero-based motor indices")
	check(Output.message(39,false).slice(-4)==PackedByteArray([44,70,0,0]),"Release packet uses OSC false type tag")
	var receiver:=PacketPeerUDP.new()
	check(receiver.bind(0,"127.0.0.1",1048576)==OK,"Loopback OSC receiver binds an ephemeral port")
	config.port=receiver.get_local_port()
	var g:=Fixture.new();root.add_child(g)
	var service:=Service.new();g.add_child(service);g.haptics=service;service.game=g;service.set_process(false)
	service.configure(config);service.set_process(false)
	var now:=Time.get_ticks_msec()*.001
	service.output.tick(now);var initial:=drain(receiver)
	check(initial.size()==40 and not any_on(initial),"Activation clears all vest motors without playing an effect")
	var before: int=service.output.packets_sent
	service.shot(2,4);check(service.output.packets_sent==before,"Remote player's shot cannot vibrate this client")
	service.shot(1,4);var shot:=drain(receiver)
	check(shot.get(Output.address(2),false) and not shot.get(Output.address(0),true),"Primary recoil uses the right chest")
	before=service.output.packets_sent;service.shot(1,4)
	check(service.output.packets_sent==before,"Sustained recoil has a bounded event rate")
	service.shot(1,4,true);var offhand:=drain(receiver)
	check(offhand.get(Output.address(0),false) and offhand.get(Output.address(2),false),"Independent offhand recoil overlaps primary recoil")
	service.output.tick(Time.get_ticks_msec()*.001+.5)
	check(not any_on(drain(receiver)),"Recoil releases even when no more gameplay events arrive")
	service.output.next_send=Time.get_ticks_msec()*.001+.25
	service.cooldowns.clear();service.shot(1,2)
	check(any_on(drain(receiver)),"Short pulses are sent immediately after an idle snapshot")
	service.stop();drain(receiver)
	service.output.pulse([0,39,-1,40,"1"],10.0,now)
	check(not service.output.states_at(now+.31).has(1),"Invalid motors are ignored and effect duration is capped")
	service.stop();drain(receiver)
	for field in ["headless","dedicated","quitting","menu_open","map_loading"]:
		g.set(field,true);before=service.output.packets_sent
		service.shot(1,4);service.hurt(1,Vector3.FORWARD,50,false);service.pickup(1,"health")
		check(service.output.packets_sent==before,"No gameplay output while "+field)
		g.set(field,false)
	g.active=false;before=service.output.packets_sent;service.shot(1,4)
	check(service.output.packets_sent==before,"Disconnected client cannot play gameplay feedback");g.active=true
	g.players[1].spectator=true;service.shot(1,4);check(service.output.packets_sent==before,"Spectators do not receive player recoil");g.players[1].spectator=false
	g.demos.playing=true;service.shot(1,4);check(not service.test_pulse() and service.output.packets_sent==before,"Demo playback suppresses effects and test pulses");g.demos.playing=false
	service.hurt(1,Vector3.BACK,50,false,true);check(service.output.packets_sent==before,"Screen-only hunger damage has no suit feedback")
	check(Service.impact_motors(Vector3.BACK,Basis.IDENTITY)==[5,6,9,10],"Incoming direction is inverted to select the front")
	check(Service.impact_motors(Vector3.FORWARD,Basis.IDENTITY)==[25,26,29,30],"Damage from behind selects the back")
	check(Service.impact_motors(Vector3.RIGHT,Basis.IDENTITY).has(0),"Damage from left selects left vest edges")
	check(Service.impact_motors(Vector3.LEFT,Basis.IDENTITY).has(3),"Damage from right selects right vest edges")
	check(Service.impact_motors(Vector3.RIGHT,Basis(Vector3.UP,PI/2))==[5,6,9,10],"Physical body rotation is included in damage direction")
	check(Service.impact_motors(Vector3.ZERO,Basis.IDENTITY).size()==8,"Missing direction uses a neutral pattern")
	service.hurt(1,Vector3.BACK,40,false);check(any_on(drain(receiver)),"Local damage emits a vest pulse")
	g.menu_open=true;service._process(0);check(not any_on(drain(receiver)),"Opening a menu releases active effects")
	check(service.test_pulse(),"Explicit test pulse works in the menu")
	check(any_on(drain(receiver)),"Menu test reaches the OSC socket")
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);check(not any_on(drain(receiver)),"Focus loss sends release packets")
	check(not service.test_pulse(),"Test pulses require focus")
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);service._process(0);check(not any_on(drain(receiver)),"Focus regain never replays stale pulses")
	g.menu_open=false;service.shot(1,4);drain(receiver)
	var receiver2:=PacketPeerUDP.new();check(receiver2.bind(0,"127.0.0.1",1048576)==OK,"Second endpoint binds")
	config.port=receiver2.get_local_port();service.configure(config);service.set_process(false)
	check(not any_on(drain(receiver)),"Changing endpoint releases the old receiver")
	service.shot(1,4);check(any_on(drain(receiver2)),"New effects use the new endpoint")
	config.enabled=false;service.configure(config)
	check(not any_on(drain(receiver2)) and service.output.udp==null,"Disabling releases motors and closes the socket")
	config.enabled=true;g.headless=true;service.configure(config)
	check(service.output.udp==null,"Headless client cannot initialize a socket from saved preferences")
	g.headless=false;g.dedicated=true;service.configure(config)
	check(service.output.udp==null,"Dedicated server cannot initialize a socket from saved preferences")
	g.dedicated=false;config.enabled=false;service.configure(config)
	var panel=load("res://deathmatch/haptics/panel.gd").new();root.add_child(panel);panel.setup(g);panel.config_path=path
	panel.host.text="127.0.0.1";panel.port.value=receiver.get_local_port();panel.enabled.set_pressed_no_signal(true);panel.save();service.set_process(false)
	check(Preferences.read_settings(path).enabled and service.output.udp!=null,"Menu applies and persists enabled endpoint")
	panel.host.text="invalid";panel.save()
	check(not Preferences.read_settings(path).enabled and service.output.udp==null,"Invalid menu endpoint persists disabled state")
	panel.free();service.shutdown();g.free();receiver.close();receiver2.close()
	print("BHAPTICS_RESULT ",JSON.stringify({"failures":failures,"packets":packets}));quit(0 if failures.is_empty() else 1)
