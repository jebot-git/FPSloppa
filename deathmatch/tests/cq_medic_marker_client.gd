extends "res://tools/voxel_battle/medic_test_arena.gd"
var capture_started:=false
func _process(delta:float)->void:
 super._process(delta)
 if not fixture_ready or capture_started:return
 capture_started=true;capture_marker.call_deferred()
func capture_marker()->void:
 set_process(false);set_physics_process(false)
 var target:int=classes.downed.keys()[0]
 var fighter=fighters[target]
 var at:Vector3=preload("res://deathmatch/conquest/classes/medic_drag_points.gd").anchor(fighter.render_position(),fighter.damage_yaw())
 camera.global_position=fighter.render_position()+Vector3(.3,1.5,1.5);camera.look_at(at);camera.make_current()
 match_mode.draw_objectives()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("/tmp/cq-cabin-display-fixes/medic-live-marker.png")
 var node:Node3D=medic_drag_points.points.get(target)
 var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,at,1))
 var row:Dictionary={"role":classes.role(multiplayer.get_unique_id()),"mine":multiplayer.get_unique_id(),"menu":menu_open,"active":active,"local_state":local_state(),"patient_state":players[target],"mode_kind":match_mode.kind,"same_team":match_mode.same_team(multiplayer.get_unique_id(),target),"target":target,"downed":classes.downed.keys(),"marker_exists":is_instance_valid(node),"visible":is_instance_valid(node) and node.visible,"anchor":at,"camera":camera.global_position,"world_cover":str(hit),"distance":camera.global_position.distance_to(at)}
 var output:=FileAccess.open("/tmp/cq-cabin-display-fixes/medic-live-marker.json",FileAccess.WRITE);output.store_string(JSON.stringify(row,"\t"));output.close()
 print("CQ_MEDIC_LIVE_MARKER ",JSON.stringify(row));disconnect_game();await get_tree().process_frame;get_tree().quit(0 if row.visible else 1)
