extends SceneTree
## Magnified geometry review: full / medium / far rows, five base model columns.
## Writes run, crouch, jump and early-death screenshots; distance policy disabled.
var rigs:Array=[]
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,900)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("24322c");root.add_child(env)
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,2.8,-10);camera.look_at(Vector3(0,2.8,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.4;camera.current=true
 var lib=load("res://deathmatch/avatars/library.gd").new();root.add_child(lib)
 for model in ["soldier","commando","sgirl","fcommando","boss"]:
  var hash=lib.register_file("res://deathmatch/avatars/models/base/"+model+".utavatar",false)
  for tier in 3:
   var rig=lib.create_avatar(hash);root.add_child(rig);rig.set_process(false);rig.tracked_arms_enabled=false;rig.mesh_lod_enabled=false;rig.position=Vector3((rigs.size()/3-2)*2, (2-tier)*2,0);rig.visual.mesh=rig.lod_meshes[tier];rigs.append(rig)
 var label=Label.new();label.text="UT99 INDEX LOD REVIEW · full / ~50% / ~25% triangles · same scale (magnified far detail)";label.position=Vector2(20,12);root.add_child(label)
 for mode in ["run","crouch","jump","death"]:
  for rig in rigs:
   rig.dead=mode=="death";rig.speed=4 if mode=="run" else 0;rig.stance="crouch" if mode=="crouch" else "stand";rig.grounded=mode!="jump";rig.time=0;rig._process(.2)
  for frame in 30:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/ut99-lod/"+mode+"-lod-review.png")
 quit()
