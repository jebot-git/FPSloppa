extends SceneTree
var game
func _initialize():run.call_deferred()
func run():
 var opts:Dictionary=JSON.parse_string(OS.get_cmdline_user_args()[0])
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map=opts.map;game.start_host("KOTH approach audit",0,100000,60,true,"koth","doom")
 game.set_process(false);game.set_physics_process(false);game.dedicated=true
 for id in game.players:game.players[id].spectator=id!=-1;game._spawn(id)
 while not game.bots.navigation.ready():await physics_frame
 game.bots.navigation.install_links()
 for i in 1600:game.bots.navigation.update_jump_links();await physics_frame
 var rows:Array=[]
 var starts:Array=[game.match_mode.spawns(0),game.match_mode.spawns(1)]
 if opts.get("survey",false):
  var candidates:Array=[];var mesh=game.bots.region.navigation_mesh;var vertices:PackedVector3Array=mesh.vertices
  for i in mesh.get_polygon_count():
   var polygon:PackedInt32Array=mesh.get_polygon(i);var point:=Vector3.ZERO
   for j in polygon:point+=vertices[j]
   point/=polygon.size()
   if point.distance_to(game.match_mode.hill)<14 or point.distance_to(game.match_mode.hill)>30:continue
   var hit:Dictionary=game.bots.navigation.ray(point+Vector3.UP*.5,point-Vector3.UP)
   if hit.is_empty() or hit.normal.y<.99:continue
   point=hit.position+Vector3.UP*.05
   if not game.bots.navigation.landing_clear(point):continue
   var path:PackedVector3Array=game.bots.navigation.path(point,game.match_mode.hill)
   if path.size()<2:continue
   var cost:float=game.bots.navigation.cost(point,game.match_mode.hill,path)
   if cost<16 or cost>34:continue
   candidates.append({"point":point,"cost":cost})
  candidates.sort_custom(func(a,b):return absf(a.cost-24)<absf(b.cost-24))
  starts=[[],[]]
  for row in candidates:
   if starts[0].any(func(p):return p.distance_to(row.point)<3.5):continue
   starts[0].append(row.point)
   if starts[0].size()>=32:break
 for team in 2:
  for origin:Vector3 in starts[team]:
   game.players[-1].team=team;game._spawn(-1)
   var actor=game.fighters[-1];actor.position=origin;actor.velocity=Vector3.ZERO;actor.reset_view()
   game.bots.brains[-1]=game.bots.new_brain(-1)
   var brain:Dictionary=game.bots.brains[-1];brain.goal=game.match_mode.hill;brain.goal_key="hill-fixture";brain.goal_kind="objective";brain.hold=true
   brain.path=game.bots.navigation.path(actor.position,brain.goal);brain.step=0
   var start:float=game.clock;var replan:float=game.clock+.8;var trace:Array=[]
   while game.clock-start<20 and actor.position.distance_to(brain.goal)>2.5:
    await physics_frame
    brain.next=game.clock+100;brain.plan_at=game.clock+100
    if game.clock>=replan and brain.path.is_empty():brain.path=game.bots.navigation.path(actor.position,brain.goal);brain.step=0;replan=game.clock+.8
    game._physics_process(1.0/60)
    if int((game.clock-start)*60)%60==0:trace.append({"p":actor.position,"path":brain.path,"step":brain.step})
   rows.append({"team":team,"start":origin,"end":actor.position,"seconds":game.clock-start,"passed":actor.position.distance_to(brain.goal)<=2.5,"trace":trace})
 FileAccess.open(opts.output,FileAccess.WRITE).store_string(JSON.stringify({"map":opts.map,"hill":game.match_mode.hill,"rows":rows},"  "))
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
