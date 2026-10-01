extends SceneTree
const Actions=preload('res://deathmatch/audio/weapon-actions/player.gd')
const Spatial=preload('res://deathmatch/audio/spatial.gd')
class Rules extends RefCounted:
	var kind:='ut99'
	func effective():return kind
class Lobby extends RefCounted:
	func active():return false
class Walkers extends RefCounted:
	func mounted(_id):return false
class Fortress extends RefCounted:
	var walkers=Walkers.new()
	var rules:='ut99'
	func art_rules(_id,_weapon):return rules
class Mode extends RefCounted:
	var fortress=Fortress.new()
class Combat extends RefCounted:
	var charges:Dictionary={}
	func visual_charge(id):return charges.get(id,0.0)
class Fixture extends Node3D:
	var headless:=false
	var quitting:=false
	var active:=true
	var map_loading:=false
	var menu_open:=false
	var intermission:=0.0
	var camera:Camera3D
	var players:Dictionary={}
	var fighters:Dictionary={}
	var armory=Rules.new()
	var lobby=Lobby.new()
	var match_mode=Mode.new()
	var variant_combat=Combat.new()
	func _weapon_transform(id):return Transform3D(Basis.IDENTITY,players[id].where)
class Mixer extends Node3D:
	var events:Array=[]
	var bank=Spatial.new()
	func play(kind,where,volume):events.append({'kind':kind,'where':where,'volume':volume})
	func choose(kind):return bank.choose(kind)
	func create_player():return AudioStreamPlayer3D.new()
	func configure(_p):pass
	func occluded(_from,_to):return false
	func count(kind):return events.filter(func(e):return e.kind==kind).size()
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
	var g:=Fixture.new();root.add_child(g);g.camera=Camera3D.new();g.add_child(g.camera)
	var mixer:=Mixer.new();g.add_child(mixer);mixer.bank.prewarm()
	var actions:=Actions.new();g.add_child(actions);actions.setup(g,mixer);actions.set_physics_process(false)
	for name in Actions.Bank.SOUNDS:
		var sound=mixer.choose('action_'+name);var row:Dictionary=Actions.Bank.SOUNDS[name]
		check(sound is AudioStreamWAV and not sound.stereo and sound.mix_rate==32000,name+' mono PCM prewarmed')
		check(sound.loop_mode==AudioStreamWAV.LOOP_FORWARD if row.loop else sound.loop_mode==AudioStreamWAV.LOOP_DISABLED,name+' loop mode correct')
		if row.loop:check(sound.loop_begin==0 and sound.loop_end==sound.data.size()/2 and sound.data.decode_s16(0)==sound.data.decode_s16(sound.data.size()-2),name+' seamless whole-stream loop')
	check(mixer.choose('action_not_a_real_sound')==null,'Unknown action cannot load arbitrary paths')
	var s=actions.state_for(1,'ut99',0,1,Vector3(1,0,0));actions.charge(s,.2);actions.advance(.1)
	check(s.loop=='hammer_charge' and mixer.count('action_hammer_start')==1,'Hammer starts charge once')
	for i in 10:actions.charge(s,.5);actions.advance(.01)
	check(mixer.count('action_hammer_start')==1,'Holding charge does not retrigger the startup')
	actions.shot(1,'ut99',0,1,s.where,.8);actions.charge(s,.5);actions.advance(.05)
	check(not s.charged and s.loop=='','Release shot stops charge despite stale snapshot')
	actions.advance(.2);actions.charge(s,0);actions.charge(s,.4);actions.charge(s,0)
	check(mixer.count('action_pressure_release')==1,'Cancelled hammer charge vents once')
	s=actions.state_for(2,'ut99',6,1,Vector3(2,0,0));actions.charge(s,.01)
	for value in [.17,.34,.51,.68,.85,1.0]:actions.charge(s,value)
	check(mixer.count('action_rocket_load')==6,'Rocket loading has six bounded stages')
	actions.shot(2,'ut99',6,1,s.where,.9);actions.state_for(2,'ut99',2,1,s.where);actions.advance(2)
	check(mixer.count('action_launcher_close')==0,'Switch cancels queued chamber sound')
	s=actions.state_for(3,'ut99',7,1,Vector3(3,0,0))
	for i in 10:actions.shot(3,'ut99',7,1,s.where,.1);actions.advance(.09)
	check(mixer.count('action_pulse_stop')==0 and s.loop=='pulse_run','Burst keeps a single active loop')
	actions.advance(.3);actions.advance(.3)
	check(mixer.count('action_pulse_stop')==1,'Burst gets exactly one wind-down')
	actions.shot(4,'cs16',9,1,Vector3.ZERO,1.45,true);actions.advance(1)
	check(mixer.count('action_bolt_cycle')==0,'Physical AWP cycling is not duplicated')
	actions.shot(4,'cs16',9,1,Vector3.ZERO,1.45,false);actions.advance(.7)
	check(mixer.count('action_bolt_cycle')==1,'Desktop AWP plays delayed bolt recovery')
	actions.state_for(5,'doom',2,1,Vector3.ZERO);actions.advance(1)
	check(actions.states[5].loop=='','Pistol has silent idle')
	actions.clear();mixer.events.clear()
	for id in range(1,17):
		g.players[id]={'weapon':7,'serial':1,'dead':false,'spectator':false,'where':Vector3(id*.4,0,0)};g.fighters[id]=true
		actions.shot(id,'ut99',7,1,g.players[id].where,.12)
	actions._physics_process(.01);actions._physics_process(.01);actions._physics_process(.04)
	check(actions.voices.size()==8,'Sixteen simultaneous weapons use at most eight loops')
	check(actions.voices.all(func(v):return v.owner<=8),'Nearest emitters receive loop voices')
	g.players[1].where=Vector3(.1,1,0);actions._physics_process(.01)
	check(actions.voices[0].player.global_position==g.players[1].where,'Emitter follows held weapon')
	g.players[1].dead=true;actions._physics_process(.01)
	check(not actions.states.has(1) and actions.voices.all(func(v):return v.owner!=1),'Death clears pending and active state')
	g.players[2].serial=2;actions._physics_process(.01)
	check(not actions.states[2].firing,'Respawn does not inherit firing state')
	g.menu_open=true;actions._physics_process(.01)
	check(actions.states.is_empty() and actions.voices.is_empty(),'Menu stops all lifecycle sources')
	g.menu_open=false;g.match_mode.fortress.rules='doom'
	for id in g.players:g.players[id].weapon=1
	actions._physics_process(.5);actions._physics_process(.1)
	check(actions.voices.size()<=8 and not actions.voices.is_empty(),'Chainsaw idle resumes within voice budget')
	g.map_loading=true;actions._physics_process(.01)
	check(actions.voices.is_empty(),'Map transition stops idle loops')
	g.map_loading=false;actions._physics_process(.6);g.quitting=true;actions._physics_process(.01)
	check(actions.states.is_empty() and actions.voices.is_empty(),'Disconnect cancels all machinery')
	g.headless=true;actions.shot(1,'ut99',7,1,Vector3.ZERO,.1)
	check(actions.states.is_empty(),'Dedicated server never creates sound state')
	mixer.bank.free();g.free();await process_frame
	print('WEAPON_ACTIONS_RESULT ',JSON.stringify({'checks':checks,'failures':failures}));quit(0 if failures.is_empty() else 1)
