extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Guide=preload("res://deathmatch/vr/ik_guide.gd")
var failures:Array=[]
var checks:=0
var g
var rig
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func tick():
 rig._process(.016)
 await process_frame;await process_frame
func capture():
 if not OS.get_cmdline_user_args().has("--render"):return
 for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
 rig.panel.hide();rig.keyboard.hide();rig.status_surface.hide();rig.damage_overlay.hide()
 for pointer in rig.pointers:pointer.hide()
 root.size=Vector2i(900,1000);root.content_scale_size=root.size
 var camera:=Camera3D.new();root.add_child(camera);camera.position=rig.global_position+Vector3(1.8,1.5,-2.3);camera.look_at(rig.global_position+Vector3(0,.85,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.25;camera.make_current()
 camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color("263441")
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/index-stacking-ik/ik-guide.png")
 camera.free()
 for layer in g.find_children("*","CanvasLayer",true,false):layer.show()
func run():
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);g.set_process(false);g.set_physics_process(false)
 g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
 rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(rig);g.xr_rig=rig;rig.setup(g,true);rig.set_process(false);rig.calibration_pending=false
 g._add_player(1,"IK guide");g.active=true;g.menu_open=true;g.hud.show_menu(true)
 var actor=g.fighters[1];actor.position=Fixture.point();actor.set_process(false)
 var hash:String=g.avatars.library.selected;actor.set_avatar(g.avatars.library.create_avatar(hash),hash);actor.show_alive(true,true)
 var settings=g.hud.settings_panel;settings.open();settings.book.navigate("tracking")
 await tick();await tick();actor._process(.016);await process_frame;await process_frame
 var guide=rig.ik_guide;var sk:Skeleton3D=actor.avatar.skeleton
 check(guide.visible and guide.skeleton==sk and actor.local_ik_guide,"Tracking settings bind the current local avatar skeleton")
 check(not actor.avatar.visible and actor.avatar.first_person and actor.avatar.process_mode==Node.PROCESS_MODE_INHERIT,"Menu hides opaque body but keeps live first-person IK running")
 check(guide.joints.size()>=14 and guide.links.size()>=13,"Guide shows limbs and torso without non-humanoid helper bones")
 check(guide.material.albedo_color.a<.6 and guide.material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Skeletal guide is transparent")
 check(guide.joints.values()[0].layers==Guide.LAYER and rig.head.cull_mask&Guide.LAYER!=0,"Guide uses a local visual layer visible to the headset")
 # Capture inside the signal: Godot resets modified poses after applying the skin.
 var samples:Array=[]
 sk.skeleton_updated.connect(func():samples.append(sk.to_global(sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin)))
 rig.left.position=Vector3(-.38,1.35,-.32);await tick();actor._process(.016);await process_frame;await process_frame
 var hand:int=sk.find_bone("LeftHand")
 check(not samples.is_empty() and guide.joints[hand].position.distance_to(samples[-1])<.0001,"Guide reads the final IK wrist rather than the rest pose")
 var previous:Vector3=guide.joints[hand].position
 rig.left.position+=Vector3(0,-.25,.18);await tick();actor._process(.016);await process_frame;await process_frame
 check(guide.joints[hand].position.distance_to(previous)>.1,"Moving a tracked hand moves the live skeletal guide")
 await capture()
 settings.book.navigate("home");await tick()
 check(not guide.visible and guide.skeleton==null and not actor.local_ik_guide,"Leaving Tracking clears the guide and releases IK preview")
 settings.book.navigate("tracking");await tick();rig.focused=false;await tick()
 check(not guide.visible and not actor.local_ik_guide,"Focus loss hides the guide")
 rig.focused=true;await tick();settings.hide();await tick()
 check(not guide.visible and not actor.local_ik_guide,"Closing settings hides the guide")
 g.active=false;settings.open();settings.book.navigate("tracking");await tick()
 check(guide.visible and is_instance_valid(guide.preview) and guide.skeleton==guide.preview.skeleton,"Main-menu calibration shows selected avatar IK before joining")
 check(not guide.preview.visible and guide.preview.first_person,"Main-menu preview is skeletal only and uses live tracking")
 g.active=true;await tick()
 check(guide.skeleton==actor.avatar.skeleton and not is_instance_valid(guide.preview),"Joining switches from private preview to the live skeleton")
 var old:Skeleton3D=actor.avatar.skeleton;actor.set_avatar(g.avatars.library.create_avatar(hash),hash);await tick()
 check(guide.skeleton!=old and guide.skeleton==actor.avatar.skeleton,"Avatar replacement safely rebinds the guide")
 settings.hide();await tick();g.free();await process_frame
 print("IK GUIDE: ",checks," checks, ",failures.size()," failures");quit(1 if failures else 0)
