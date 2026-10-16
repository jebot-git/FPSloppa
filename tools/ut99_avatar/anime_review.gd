extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func run()->void:
 var library:=Library.new();root.add_child(library)
 var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json")).filter(func(row):return row.get("bundle","")=="anime")
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.8;camera.position=Vector3(0,3.,-10);camera.look_at(Vector3(0,3.,0));camera.make_current();root.size=Vector2i(1920,1400)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.10,.12,.16);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.75;world.add_child(environment)
 var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-30,160,0);sun.light_energy=1.1
 var avatars:Array=[]
 for i in rows.size():
  var row:Dictionary=rows[i]
  if FileAccess.get_sha256(row.path)!=row.hash:failures.append("hash "+row.title);continue
  var decoded:Dictionary=preload("res://deathmatch/avatars/ut_format.gd").read(row.path)
  if decoded.has("error"):failures.append(row.title+": "+str(decoded.error));continue
  var avatar=library.create_avatar(row.hash)
  if not avatar:failures.append("create "+row.title);continue
  world.add_child(avatar);avatar.position=Vector3((i%5-2)*1.55,(2-floori(i/5.))*2.1,0);avatar.set_process(false);avatar.preview_mode=0;avatar.distance_ik_enabled=false;avatars.append(avatar)
  var label:=Label3D.new();world.add_child(label);label.position=avatar.position+Vector3(0,-.17,0);label.text=row.title.replace("Motoko Kusanagi","Original").replace("Team Anime · ","").replace("Kusanagi · Motoko (Rumiko)","Kusanagi / Rumiko");label.font_size=36;label.pixel_size=.001;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 var render:bool=DisplayServer.get_name()!="headless"
 for tracked in [false,true]:
  for avatar in avatars:
   avatar.target_xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.1,-.4)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.4)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.1,-.4))} if tracked else {}
   avatar.advance_animation(.3)
   if not avatar.transform.is_finite():failures.append("nonfinite avatar transform")
  if render:
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/tmp/cq-anime-"+("tracked" if tracked else "idle")+".png")
 print("ANIME_BUNDLE_REVIEW ",JSON.stringify({"avatars":avatars.size(),"expected":rows.size(),"rendered":render,"failures":failures}))
 world.free();library.free();quit(0 if failures.is_empty() and avatars.size()==13 else 1)
