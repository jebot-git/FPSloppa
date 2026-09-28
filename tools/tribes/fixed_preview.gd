extends SceneTree
var g
func _initialize():run.call_deferred()
func run():
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Fixed defence preview",0,100,30,true,"st")
 g.set_process(false);g.set_physics_process(false);g.menu_open=false;g.hud.hide();root.size=Vector2i(1280,800)
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 if is_instance_valid(g.viewmodel):g.viewmodel.hide()
 var origin:=Vector3(1000,80,1000);var kinds=["fusion","mini","elf","missile","mortar"]
 var art=preload("res://deathmatch/art.gd")
 art.box(g,origin-Vector3.UP*.25,Vector3(36,.5,12),art.material(Color("39434d"),.4))
 for i in kinds.size():
  var model=preload("res://deathmatch/tribes/fixed_defence_model.gd").make(kinds[i],i%2);g.add_child(model);model.global_position=origin+Vector3((i-2)*6.0,0,0);model.get_node("Status").text=kinds[i].to_upper()
 g.camera.global_position=origin+Vector3(9,8,-24);g.camera.look_at(origin+Vector3(0,1,0));g.camera.fov=75
 for frame in 12:await process_frame
 root.get_texture().get_image().save_png("res://test-results/st-tribes/parity123/fixed-gallery.png")
 var rules=g.match_mode.tribes;var fixed=rules.stations().defences
 g.players[1].team=fixed.rows[0].team;g.players[1].input_blocked=false
 fixed.control(1,0,g.map_epoch,g.players[1].serial)
 fixed.rows[0].aim=(g.match_mode.bases[1]-fixed.eye(0)).normalized()
 if not is_instance_valid(rules.turret_view):rules.turret_view=preload("res://deathmatch/tribes/turret_view.gd").new();g.add_child(rules.turret_view);rules.turret_view.setup(rules)
 rules.turret_view.update()
 for frame in 12:await process_frame
 root.get_texture().get_image().save_png("res://test-results/st-tribes/parity123/turret-panel.png")
 print("FIXED_PREVIEW_READY")
 g.disconnect_game();g.free();quit()
