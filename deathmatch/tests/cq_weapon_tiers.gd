extends SceneTree
const Runtime=preload("res://deathmatch/native/runtime.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Progression=preload("res://deathmatch/conquest/classes/progression.gd")
var failures:Array=[]
var checks:=0
class ThermalFixture extends Node3D:
 var active:=true
 var menu_open:=false
 var players:Dictionary={}
 var fighters:Dictionary={}
 func local_state()->Dictionary:return {"team":0,"weapon":10,"dead":false}
 func is_vr()->bool:return false
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 Engine.physics_ticks_per_second=30
 var armory=preload("res://deathmatch/conquest/classes/armory.gd").new();armory.select("ut99")
 var progression:=Progression.new()
 var classes:Array=["shocktroop","scout","medic","technician"]
 var tiers:Array=[[4,1,14],[9,10,16],[3,12,13],[5,11,15]]
 for role in 4:
  for tier in 3:
   var unlocked:Array=progression.unlocked(classes[role],[0,2500,5000][tier])
   check(unlocked==tiers[role].slice(0,tier+1),"XP tier mapping %s:%d"%[classes[role],tier])
 check(armory.data(3).kind=="nail" and armory.data(12).kind=="nail" and armory.data(13).kind=="nail","all medic tiers are SMGs")
 check(armory.data(14).burst==3 and armory.data(16).range>=1000 and armory.data(16).thermal_range==150.,"burst/railgun capabilities")
 var world:=Node3D.new();root.add_child(world)
 for slot in [0,1,2,3,4,5,7,8,9,10,11,12,13,14,15,16]:
  var node:Node3D=Models.weapon(slot,"cq_technician");world.add_child(node)
  var data:Dictionary=Models.metadata(slot,"cq_technician")
  check(data.triangles<=data.get("triangle_budget",5000),"weapon triangle budget "+str(slot))
  check(is_instance_valid(node.find_child("AlignedRedDot",true,false))==(slot in [1,4]),"red dot attachment policy "+str(slot))
  if slot not in [7,8]:
   var magazine=node.find_child("InsertedAmmo",true,false);check(magazine!=null,"independent magazine "+str(slot))
   if magazine:
    var source:Vector3=magazine.position
    Models.animate_reload(node,{"mag":false,"stroke":.7,"locked":true,"ready":false})
    check(not magazine.visible and magazine.position==source,"ejection hides inserted geometry "+str(slot))
    Models.animate_reload(node,{"mag":true,"stroke":0.,"ready":true})
    check(magazine.visible,"reinsertion restores magazine "+str(slot))
  if slot in [0,2,9]:check(node.find_child("SlidingBolt",true,false)!=null,"pistol has authored moving slide")
  if slot in [5,11,15]:check(node.find_child("ChargingHandle",true,false)==null and data.reload_kind=="pack","ordnance and minigun use timed pack reload")
  if slot in [3,12,13]:check(data.get("aim_laser",false) and not node.has_meta("cq_zoom"),"medic optic is a laser projector")
  if slot==10:check(data.get("scope_monitor",false),"T2 scout has offhand-side optic monitor")
  if slot==16:check(data.display_anchor[1]>.25 and data.display_rotation==[0.,0.,0.] and data.display_size[0]<.1,"thermal panel matches small rear-facing authored screen")
  if slot==14:check(data.zoom_steps==[1.5] and node.has_meta("scope_rear") and node.get_meta("red_dot"),"modeled burst optic fixed to 1.5x red dot")
  if slot==10:
   var receiver:=node.find_child("ReloadReceiver",true,false)
   check(receiver!=null and data.get("magazine_reload_path",[]).size()>10,"beam rifle retains source receiver and cell reload path")
   if receiver:
    for i in 5:
     node.set_meta("reload_time",Time.get_ticks_msec()*.001-.1);Models.animate_reload(node,{"mag":false})
    check(receiver.position.length()>.02,"removing beam cell opens the authored receiver")
    for i in 5:
     node.set_meta("reload_time",Time.get_ticks_msec()*.001-.1);Models.animate_reload(node,{"mag":true})
    check(receiver.position.length()<.001,"inserting beam cell closes the authored receiver")
  node.free()
 check(Models.metadata(9,"cq_scout").triangles>4500 and Models.metadata(14,"cq_shocktroop").triangles>6000,"scout and burst retain detailed source geometry")
 var kick=preload("res://deathmatch/vr/weapon_kick.gd").new();kick.shot(14,false);var unsupported:float=kick.target.x;kick.reset();kick.shot(14,true)
 check(kick.target.x<unsupported,"offhand grip reduces physical recoil")
 var thermal_game:=ThermalFixture.new();world.add_child(thermal_game)
 var monitor_gun:Node3D=Models.weapon(10,"cq_scout");thermal_game.add_child(monitor_gun)
 for child in monitor_gun.get_children():
  if child.get_script()==load("res://deathmatch/conquest/classes/scout_monitor.gd"):
   child._process(.1);check(child.visible and child.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS and child.camera.cull_mask&(1<<19)==0,"scout monitor renders projection without recursive weapon/HUD view")
 monitor_gun.free()
 var thermal_gun:Node3D=Models.weapon(16,"cq_scout");thermal_game.add_child(thermal_gun)
 for i in 3:
  var actor:=Node3D.new();thermal_game.add_child(actor);actor.position=Vector3(0,0,-149. if i==0 else -151. if i==1 else -50.)
  thermal_game.fighters[i]=actor;thermal_game.players[i]={"team":0 if i==2 else 1,"dead":false,"spectator":false}
 var display
 for child in thermal_gun.get_children():
  if child.get_script()==load("res://deathmatch/conquest/classes/thermal_display.gd"):display=child
 check(display!=null,"railgun has a weapon-mounted thermal display")
 if display:
  display._process(.11);check(display.screen.targets.size()==1,"thermal tracker excludes friends and enemies beyond 150m")
 thermal_game.free()
 var authority
 check(Runtime.available("FPSAuthority"),"native authority available")
 authority=ClassDB.instantiate("FPSAuthority");authority.configure_world(world);authority.configure_cq({"auto_respawn":false});authority.configure_frames(true)
 var life_ids:Array=[]
 for role in 4:
  var actor:=CharacterBody3D.new();var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.3;cylinder.height=1.65;shape.shape=cylinder;shape.position.y=.825;actor.add_child(shape);world.add_child(actor);actor.position=Vector3(role*10,2,0)
  var life:int=authority.attach_actor(role+1,actor,shape,role%2,1<<2,PackedInt32Array([100,100,100,100]));life_ids.append(life)
  check(life>0,"attach tier fixture")
  var profile:Dictionary={"role":role,"next":role,"xp":[7500,7500,7500,7500],"primary":0,"primary3":1<<role,"secondary":0,"utility":0}
  check(authority.configure_player(role+1,life,profile),"native T3 profile "+str(role))
 for tick in 4:
  await physics_frame;check(authority.advance(),"advance CQ3 fixture")
 var raw:PackedByteArray=authority.snapshot();var frame:Dictionary=Codec.decode_frame(raw)
 check(not frame.is_empty() and frame.get("version",0)==3,"CQ3 expanded frame roundtrip")
 if not frame.is_empty():
  for role in 4:
   var p:Dictionary=frame.players[role+1];var slot:int=tiers[role][2]
   check(p.weapon==slot and p.owned.has(slot),"expanded ownership roundtrip "+str(role))
   check(p.clips.size()==17 and p.clips[slot]==armory.data(slot).magazine,"extended magazine roundtrip "+str(role))
   var command:Dictionary={"life":life_ids[role],"seq":0,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":slot,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
   check(authority.submit(role+1,command),"T3 input accepted by native adapter "+str(role))
  var presented:Array=Presentation.project(frame,0.,1,120.)
  check(not presented.is_empty(),"CQ3 presentation projection")
 for role in 4:authority.detach_actor(role+1,life_ids[role])
 authority=null;world.free();await process_frame
 print("CQ_WEAPON_TIERS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
