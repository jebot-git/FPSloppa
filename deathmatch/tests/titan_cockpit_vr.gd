extends SceneTree
var failures:Array=[]
var g
var trackers:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func frames(count:int):
 for i in count:
  g._process(1./60.)
  await process_frame
func run():
 root.size=Vector2i(1280,800)
 for side in 2:
  var tracker:=XRControllerTracker.new();tracker.name="left_hand" if side==0 else "right_hand";XRServer.add_tracker(tracker);trackers.append(tracker)
  var pose:=Transform3D(Basis.IDENTITY,Vector3(-.42 if side==0 else .42,1.29,-.43))
  tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_pose("aim",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
  tracker.set_input("grip",0.);tracker.set_input("trigger",0.)
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.start_host("Cockpit VR test",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var w=g.match_mode.fortress.walkers;var r:Dictionary=w.robots.values()[0];var actor=g.fighters[1]
 actor.position=w.transform(r)*w.LADDER;g.players[1].input_blocked=false
 await physics_frame;await physics_frame
 check(w.try_board(1,r.id),"VR test boards actual Ashfall robot")
 g.xr_rig.calibration_pending=false;g.xr_rig.origin_offset=Vector3.ZERO;g.xr_rig.origin.transform=Transform3D.IDENTITY
 g.xr_rig.head.position=Vector3(0,1.65,0);g.xr_rig.head.rotation=Vector3.ZERO
 await frames(60)
 check(g.is_vr() and g.xr_rig.simulated,"Real VR rig runs with synthetic tracking")
 check(actor.local_body_visible and actor.avatar.visible,"Pilot avatar is enabled in first person")
 var geometry:Array=actor.avatar.find_children("*","GeometryInstance3D",true,false)
 check(not geometry.is_empty() and geometry.all(func(mesh):return mesh.layers&w.cockpit.PRIVATE_LAYER),"Pilot body meshes are visible to private cockpit camera")
 check(g.camera.cull_mask==w.cockpit.PRIVATE_LAYER and not w.cockpit.sensor.cull_mask&w.cockpit.PRIVATE_LAYER,"Exterior is visible only through monitor")
 var command:Dictionary=g._local_command()
 check(command.pilot_controls[0][0]==false,"Unheld VR sticks remain automatic")
 trackers[0].set_input("grip",1.);trackers[0].set_input("trigger",1.)
 await frames(4);command=g._local_command()
 check(command.pilot_controls[0][0] and command.pilot_controls[0][2] and not command.fire and not command.melee,"Left physical grip and trigger control cannon without firing fist")
 g._accept_input(1,command)
 check(w.manual_controls(r).size()==2 and w.manual_controls(r)[0][0],"Tracked cockpit control reaches authoritative validation")
 g.xr_rig.head.rotation.x=-.4
 await frames(8);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/live-crashes-0.11v/cockpit-vr-body.png")
 w.cockpit.feed.get_texture().get_image().save_png("res://test-results/live-crashes-0.11v/cockpit-monitor.png")
 r.pitches=[0.,0.];await frames(3)
 var level:Array=w.cockpit.aim_points(r)
 r.pitches=[-.35,-.35];await frames(3)
 var raised:Array=w.cockpit.aim_points(r)
 check(raised[0].y<level[0].y-50 and raised[1].y<level[1].y-50,"Both monitor reticles rise with actual cannon elevation")
 r.pitches=[.35,.35];await frames(3)
 var lowered:Array=w.cockpit.aim_points(r)
 check(lowered[0].y>level[0].y+50 and lowered[1].y>level[1].y+50,"Both monitor reticles descend with actual cannon elevation")
 r.pitches=[-.35,-.35];await frames(3);await RenderingServer.frame_post_draw
 w.cockpit.feed.get_texture().get_image().save_png("res://test-results/tb-controls-optics/cockpit-elevated.png")
 g.menu_open=true;command=g._local_command()
 check(not command.pilot_controls[0][0],"Opening menu relinquishes physical control")
 g.menu_open=false;g.xr_rig.focused=false;command=g._local_command()
 check(not command.pilot_controls[0][0],"Focus loss cannot leave a cannon firing")
 g.xr_rig.focused=true;w.leave(1,true);await frames(3)
 check(geometry.all(func(mesh):return not mesh.layers&w.cockpit.PRIVATE_LAYER),"Exiting restores original avatar render layers")
 check(not w.cockpit.interior.visible and g.camera.cull_mask!=w.cockpit.PRIVATE_LAYER,"Exiting restores world view and hides cockpit")
 g.disconnect_game();g.free();await process_frame
 for tracker in trackers:XRServer.remove_tracker(tracker)
 print("TITAN_COCKPIT_VR_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
