extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Native=preload("res://deathmatch/native/animation.gd")
var output:="/tmp/cq-avatar-runtime.json"
var frames:=120
func _initialize()->void:run.call_deferred()
func reset(rigs:Array,scenario:String)->void:
 for i in rigs.size():
  var rig=rigs[i];rig.time=0.;rig.clip_name="";rig.tracking_yaw=0;rig.rotation=Vector3.ZERO;rig.ik_weight=0.;rig.ik_near=true;rig.mesh_tier=0;rig.visual.mesh=rig.lod_meshes[0]
  rig.position=Vector3((i%8-4)*.35,0,-2-float(i/8)*.35) if scenario=="close" else Vector3((i%8-4)*7,0,-3-float(i/8)*14)
  rig.speed=5.;rig.grounded=true;rig.stance="stand";rig.dead=false;rig.firing=0.
  rig.target_xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.3,1.2,-.4)),"right":Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.6)),"weapon":Transform3D(Basis.IDENTITY,Vector3(.3,1.3,-.6))}
func run()->void:
 var args:=OS.get_cmdline_user_args()
 if args.has("--output"):output=args[args.find("--output")+1]
 if args.has("--frames"):frames=clampi(int(args[args.find("--frames")+1]),30,1000)
 var library:=Library.new();root.add_child(library)
 var hash:=library.register_file("res://deathmatch/avatars/models/base/soldier.utavatar",false)
 var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,1.7,0);camera.make_current();camera.fov=85
 var pool:Array=[]
 for i in 64:
  var rig=library.create_avatar(hash);root.add_child(rig);rig.set_weapon(1,"cq_shocktroop");rig.set_equipment("jetpack");pool.append(rig)
 var rows:Array=[]
 for scenario in ["mixed","close"]:
  for count in [8,32,64]:
   var rigs:Array=pool.slice(0,count)
   var kernel=Native.create();assert(kernel!=null,"Native animation required for benchmark")
   for rig in rigs:
    if not kernel.configure(rig,rig.clips,rig.arm_profile,rig.lod_meshes):push_error("Native animation configuration failed");quit(1);return
   for mode in ["gdscript","native_individual","native_batch"]:
    reset(rigs,scenario)
    var timings:Array=[]
    for frame in frames+30:
     var start:=Time.get_ticks_usec()
     if mode=="native_batch":kernel.advance(1./90,camera)
     else:
      for rig in rigs:
       if mode=="gdscript":rig._process_reference(1./90)
       else:rig.advance_animation(1./90)
     if frame>=30:timings.append((Time.get_ticks_usec()-start)/1000.)
    timings.sort();var sum:=0.;var tracked:=0
    for t in timings:sum+=t
    for rig in rigs:
     if rig.tracked_arms_active:tracked+=1
    var row:Dictionary={"scenario":scenario,"actors":count,"tracked":tracked,"mode":mode,"mean_ms":sum/timings.size(),"p95_ms":timings[int(timings.size()*.95)],"max_ms":timings[-1],"frames":timings.size()}
    rows.append(row);print("AVATAR_RUNTIME_SAMPLE ",JSON.stringify(row))
   kernel=null
 var report:Dictionary={"scope":"CPU animation update and engine uniform/transform submission only, same authored Soldier asset and tracked input. No physics, AI, networking or rendered-frame pacing measurement. Mixed distances and an intentionally crowded all-near worst case. 30 warm-up updates before each measurement.","engine":Engine.get_version_info().string,"rows":rows}
 DirAccess.make_dir_recursive_absolute(output.get_base_dir());FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 for rig in pool:rig.free()
 library.free();camera.free();print("AVATAR_RUNTIME_SAVED ",output);quit()
