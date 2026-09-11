extends SceneTree
const Runtime=preload("res://deathmatch/maps/runtime.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	check(Runtime.push_velocity({"angle":"-1","speed":"850"},1).is_equal_approx(Vector3.UP*26.5625),"Legacy HiSlop launch force remains calibrated")
	check(Runtime.push_velocity({"angle":"-1","speed":"850","fpsloppa_push_scale":"1"}).y==26.5625,"New generated pads explicitly select native force scale")
	check(Runtime.push_velocity({"angles":"0 1 0","speed":"100"})==Vector3.UP*31.25,"Quake vertical sentinel is recognized")
	check(Runtime.push_velocity({"angles":"0 90 0","speed":"100"}).is_equal_approx(Vector3.LEFT*31.25),"Horizontal accelerators do not invent upward force")
	check(Runtime.push_velocity({"angles":"broken"}).is_zero_approx(),"Malformed launch angles are rejected")
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="lqdm3";game.start_host("Pad test",0,100,10,true)
	game.set_process(false);game.set_physics_process(false);game.bots.free();game.bots=null
	var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
	var actor=game.fighters[1]
	for id in game.players:game.fighters[id].position=Vector3(10000+id*3,10000,10000)
	var pads: Array=runtime.regions.filter(func(region):return region.kind=="trigger_push")
	check(pads.size()==3,"Actual Hyperborea BSP contains three launch ramps")
	for i in pads.size():
		var region: Dictionary=pads[i];var shape: CollisionShape3D=region.area.get_children().filter(func(node):return node is CollisionShape3D)[0]
		actor.position=shape.global_position-Vector3.UP*.75;actor.velocity=Vector3.ZERO
		await physics_frame;await physics_frame
		check(region.area.overlaps_body(actor),"Hyperborea ramp %d brush detects player"%i)
		game.demos.events.clear();game.demos.recording=true
		runtime._physics_process(1.0/60)
		runtime._physics_process(1.0/60)
		check(game.demos.events.size()==1 and game.demos.events[0][1][0]=="jump_pad","Pad %d emits one replicated/demo feedback event per entry"%i)
		game.demos.recording=false
		var expected:=Runtime.push_velocity(region.data)
		check(actor.velocity.is_equal_approx(expected) and expected.y>17 and Vector2(expected.x,expected.z).length()>4,"Hyperborea ramp %d applies pitched launch at Quake scale"%i)
		var start: Vector3=actor.position
		for tick in 8:actor.simulate(Vector2.ZERO,0,false,1.0/60)
		check(actor.position.y>start.y+.25,"Hyperborea ramp %d lifts player in real map collision"%i)
	Fixture.setup(game);actor.position=Fixture.point();actor.update_height(1.65,true)
	var target=game.fighters[-1];target.position=actor.position+Vector3(.4,0,0)
	var state: Dictionary=game.players[-1];state.dead=false;state.spectator=false;state.hp=100;state.armor=200;state.invulnerable=game.clock+30
	game.players[1].team=0;state.team=0;game.match_mode.kind="tdm";game.match_mode.friendly_fire=false
	runtime.telefrag(1)
	check(state.dead,"Portal telefrag clears armored, spawn-protected teammate despite friendly-fire setting")
	state.dead=false;state.hp=100;target.position=actor.position+Vector3.UP*2
	runtime.telefrag(1);check(not state.dead,"Telefrag respects vertical capsule separation")
	target.position=actor.position;state.spectator=true
	runtime.telefrag(1);check(not state.dead,"Spectators cannot be telefragged")
	state.spectator=false;game.match_mode.kind="ft";game.match_mode.special.frozen[-1]=0.0
	var deaths: int=state.deaths;var kills: int=game.players[1].kills
	runtime.telefrag(1)
	check(state.dead and not game.match_mode.special.frozen.has(-1) and state.deaths==deaths and game.players[1].kills==kills,"Frozen blocker is removed without awarding a second kill")
	var stream=load("res://deathmatch/audio/jump_pad.wav")
	check(stream is AudioStream and stream.get_length()>.3,"Launch feedback has an imported sound asset")
	game.free();await process_frame;print("PAD_TELEFRAG_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
