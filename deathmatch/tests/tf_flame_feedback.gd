extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
 g.start_host("Flame feedback",0,100,60,true,"tf","quake")
 g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false)
 g.presentation.spatial_audio="builtin"
 g.menu_open=false;g.hud.hide()
 var s:Dictionary=g.players[1];s.tf_class="pyro";s.team=0;s.weapon=7;s.owned=[7];s.ammo=[0,0,0,30];s.cooldown=0;s.invulnerable=0;s.pitch=0;s.yaw=0;s.vr_device=false
 var target:Dictionary=g.players[-1];target.team=1;target.hp=1000;target.armor=0;target.invulnerable=0
 g.fighters[1].position=Fixture.point();g.fighters[-1].position=Fixture.point(0,-5)
 for id in [-2,-3]:g.players[id].spectator=true;g.fighters[id].position=Fixture.point(15,15)
 g.camera.global_position=Fixture.point(4,-1)+Vector3.UP*2.7;g.camera.look_at(Fixture.point(0,-3)+Vector3.UP)
 await physics_frame;await physics_frame
 check(g.demos.start_record("res://test-results/tb-controls-optics/flame-%d.fpsdemo"%Time.get_ticks_usec()),"Record actual network/demo effect events")
 check(g.variant_combat.fire(1),"Quake Pyro fires through authoritative combat")
 check(s.ammo[3]==29 and target.hp<1000 and g.match_mode.fortress.burns.has(-1),"Flame retains ammo, direct damage and burning")
 var events:Array=g.demos.events.duplicate(true)
 check(events.any(func(e):return e[0]=="_ability_fx" and e[1][0]=="flame"),"Shot sends flame effect to clients and demo playback")
 check(not events.any(func(e):return e[0]=="_impacts"),"Flame does not send bullet impact or tracer effects")
 check(is_instance_valid(g.ability_effects) and not g.ability_effects.bursts.is_empty(),"Real flame geometry is visible")
 check(g.spatial.active.any(func(p):return p.stream==g.spatial.choose("flamethrower")),"Pyro plays the dedicated flame jet sound")
 check(not g.spatial.active.any(func(p):return p.stream.resource_path.contains("quake_weapon_7")),"No nailgun report accompanies the flame")
 check(g.camera.find_children("*","OmniLight3D",false,false).is_empty(),"Flame does not create a machinegun muzzle flash light")
 if DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/tb-controls-optics/flamethrower.png")
 g.demos.stop_record()
 # Ordinary nailgun feedback still uses the Quake report after class change.
 s.tf_class="heavy";g._play_variant_shot_fx(1,7,false)
 check(g.spatial.active[-1].stream.resource_path.contains("quake_weapon_7"),"Ordinary slot 7 keeps its own sound")
 print("TF_FLAME_FEEDBACK_RESULT ",JSON.stringify(failures))
 g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
