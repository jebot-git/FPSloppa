extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const FX=preload("res://deathmatch/experimental/visuals.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,900)
 var stage:=Node3D.new();root.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("151c26");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.8;stage.add_child(env)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,2,9);camera.look_at(Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12
 var light:=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-40,-20,0)
 for slot in [2,3,9]:
  var y:float=2.4-[2,3,9].find(slot)*2.4
  var gun:=Art.weapon(slot,2,"quake");stage.add_child(gun);gun.position=Vector3(-4,y,0);gun.rotation.y=-PI/2
  var start:Vector3=gun.to_global(Art.muzzle(slot,"quake"))
  var effect:=FX.new();stage.add_child(effect);effect.set_process(false)
  var ends:=PackedVector3Array()
  for i in (6 if slot==2 else 14 if slot==3 else 1):ends.append(Vector3(4,y+(i-(2.5 if slot==2 else 6.5 if slot==3 else 0))*.035,0))
  effect.impacts("quake",start,ends,slot);effect._process(.01)
  check(effect.shapes.size()==(2 if slot==9 else ends.size()),"Visible rail trail or pellet streaks are emitted for Quake slot "+str(slot))
  if slot!=9:
   check(effect.particles.any(func(p):return p.smoke),"Shotgun hits emit a visible impact puff: "+str(slot))
   check(Art.muzzle(slot,"quake").z<-.83,"Shotgun effects start beyond the model front face: "+str(slot))
  check(effect.shapes.size()<=effect.MAX_SHAPES and effect.particles.size()<=effect.MAX_PARTICLES,"Effects remain within VR budgets: "+str(slot))
  var label:=Label3D.new();stage.add_child(label);label.text="SHOTGUN" if slot==2 else "SUPER SHOTGUN" if slot==3 else "RAILGUN";label.position=Vector3(-3,y-.6,.1);label.font_size=38;label.pixel_size=.004
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/live-crashes-0.11v/quake-shot-effects.png")
 stage.free();print("QUAKE_SHOT_EFFECTS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
