extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);print("FAIL ",label)
func _initialize():run.call_deferred()
func run():
 var key: String=OS.get_cmdline_user_args()[0]
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=key
 g.start_host("Classic acceptance",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
 if g.current_map!=key:check(false,"Selected map failed to load");finish();return
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var r=g.match_mode.tribes;var pads=r.stations();var c=r.vehicles
 await physics_frame;await physics_frame
 var space: PhysicsDirectSpaceState3D=g.get_world_3d().direct_space_state
 var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.65
 check(Maps.supports_tribes("res://maps/"+key+".bsp"),"ST compatibility")
 check(key in g.maps_for_mode("st") and key not in g.maps_for_mode("ctf"),"Dedicated ST map selection")
 check(pads.playable_bounds.size.length()>100,"Playable bounds")
 var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/T2Classic/"+key+"/probes.json"))
 check(pads.rows.size()==probes.stations.size(),"All authored stations instantiated")
 for team in 2:
  check(g.ctf_spawns[team].size()>=4,"Team %d spawn population"%team)
  for point in g.ctf_spawns[team]:
   var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=1;q.transform.origin=point+Vector3.UP*.85
   check(space.intersect_shape(q).is_empty(),"Team %d spawn capsule %s"%[team,point])
  var flag: Vector3=g.match_mode.bases[team]
  check(flag.distance_to(g.match_mode.bases[1-team])>40,"Flag separation")
  var s: Dictionary=g.players[1];s.team=team;s.dead=false;s.spectator=false;s.input_blocked=false;s.invulnerable=0
  r.apply_equipment(1,"light",[3,2,0],"energy")
  for f in 2:g.match_mode.return_flag(f)
  g.fighters[1].position=g.match_mode.bases[1-team];g.match_mode.tick(.05)
  check(g.match_mode.flags[1-team].carrier==1,"Team %d authoritative flag pickup"%team)
  var before: int=g.match_mode.scores[team];g.fighters[1].position=flag;g.match_mode.tick(.05)
  check(g.match_mode.scores[team]==before+1,"Team %d authoritative capture"%team)
 for i in pads.rows.size():
  var row: Dictionary=pads.rows[i];var t: int=maxi(0,row.team)
  g.players[1].team=t;g.fighters[1].position=row.position;g.fighters[1].velocity=Vector3.ZERO
  check(pads.connected(row),"Station %d starts powered"%i)
  check(pads.at(1,[row.kind])>=0,"Station %d service reachable"%i)
  if row.team==-1:
   g.players[1].team=1;check(pads.at(1,[row.kind])>=0,"Neutral station accepts both teams")
  if row.kind=="vehicle":
   for kind in c.Data.KINDS:
    c.reset();g.clock+=1;r.energy[t]=10000
    check(c.purchase(1,g.map_epoch,g.players[1].serial,kind),"Pad %d purchases %s"%[i,kind])
    c.reset()
 check(g.bots.region.navigation_mesh!=null and g.bots.region.navigation_mesh.get_polygon_count()>0,"Prepared navigation available")
 finish()
func finish():
 var key: String=OS.get_cmdline_user_args()[0];var report:={"id":key,"checks":checks,"failures":failures}
 FileAccess.open("res://test-results/t2-classic/"+key+"/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CLASSIC_ACCEPTANCE ",JSON.stringify(report));g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
