extends SceneTree
const Models=preload("res://deathmatch/tribes/models.gd")
const Replacement=preload("res://deathmatch/tribes/body_replacement.gd")
const Mask=preload("res://deathmatch/avatars/first_person_mask.gd")
const ArmourVisual=preload("res://deathmatch/tribes/armour_visual.gd")
class Stage extends Node3D:
	var players: Dictionary={}
	var local_yaw:=0.0
	func is_vr() -> bool:return false
var checks:=0
var failures: Array=[]
var test_hash:=""
var output_key:=""
var output_dir:="res://test-results/avatars-cc0/"
var actors: Array=[]
var bodies: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func count(mesh: Mesh) -> int:
	if not mesh:return 0
	var n:=0
	for i in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(i);n+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null else a[Mesh.ARRAY_VERTEX].size())/3
	return n
func _initialize():run.call_deferred()
func check_cuffs(replacement,sk: Skeleton3D,label: String):
	var mesh: Mesh=replacement.body.get_meta("full_body_mesh",replacement.body.mesh)
	var skin: Skin=replacement.body.skin
	for hand in ["LeftHand","RightHand"]:
		var wrist:=sk.find_bone(hand);var elbow:=sk.find_bone(hand.trim_suffix("Hand")+"LowerArm")
		var start:=sk.get_bone_global_rest(elbow).origin;var end:=sk.get_bone_global_rest(wrist).origin
		var axis:=end-start;var cuff_vertices:=0;var max_error:=0.0;var furthest:=0.0
		for surface in mesh.get_surface_count():
			var a:=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride: int=bones.size()/vertices.size()
			var used: Dictionary={}
			for index in a[Mesh.ARRAY_INDEX]:used[index]=true
			for index in used:
				var arm_weight:=0.0;var hand_weight:=0.0
				for j in stride:
					var name_here:=skin.get_bind_name(bones[index*stride+j])
					if name_here==hand:hand_weight+=weights[index*stride+j]
					if name_here==hand.trim_suffix("Hand")+"LowerArm":arm_weight+=weights[index*stride+j]
				if arm_weight+hand_weight<.99:continue
				furthest=maxf(furthest,(vertices[index]-end).dot(axis.normalized()))
				if (vertices[index]-start).dot(axis)/axis.length_squared()<.87:continue
				cuff_vertices+=1
				# Out-of-reach tracked wrists translate independently of the elbow;
				# test translation plus a full turn against the actual skin weights.
				for rotation in [0.0,PI/2,PI]:
					var rest:=sk.get_bone_global_rest(wrist)
					var wrist_pose:=Transform3D(Basis(Vector3.FORWARD,rotation)*rest.basis,rest.origin+Vector3(.3,.25,-.4))
					var expected:=wrist_pose*rest.affine_inverse()*vertices[index]
					var posed:=Vector3.ZERO
					for j in stride:
						var bind:=bones[index*stride+j];var bone:=sk.find_bone(skin.get_bind_name(bind))
						posed+=(wrist_pose if bone==wrist else sk.get_bone_global_rest(bone))*skin.get_bind_pose(bind)*vertices[index]*weights[index*stride+j]
					max_error=maxf(max_error,posed.distance_to(expected))
		check(cuff_vertices>=8 and max_error<.0001,label+" "+hand+" sleeve stays fixed to wrist under reach and rotation")
		check(furthest<.04,label+" "+hand+" has cuff only, without duplicate generated glove")
	for node in replacement.avatar.visual_meshes:
		if node==replacement.body or not node.visible:continue
		var retained: Mesh=node.mesh;var fixed:=true
		for surface in retained.get_surface_count():
			var a:=retained.surface_get_arrays(surface);var stride: int=a[Mesh.ARRAY_BONES].size()/a[Mesh.ARRAY_VERTEX].size()
			for vertex in a[Mesh.ARRAY_INDEX]:
				var hand_weight:=0.0
				for j in stride:
					var bind: int=a[Mesh.ARRAY_BONES][vertex*stride+j]
					var bone: int=sk.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
					while bone>=0:
						if sk.get_bone_name(bone) in ["LeftHand","RightHand"]:hand_weight+=a[Mesh.ARRAY_WEIGHTS][vertex*stride+j];break
						bone=sk.get_bone_parent(bone)
				if hand_weight>.15 and hand_weight<.9999:fixed=false
		check(fixed,label+" retained hand edges share wrist transform without forearm lag")
func check_assets():
	for key in ["light","medium","heavy"]:
		var asset:=Models.model("body_"+key)
		var meshes:=asset.find_children("*","MeshInstance3D",true,false)
		check(meshes.size()==1,key+" uses one skinned body mesh")
		var mesh: Mesh=meshes[0].mesh
		check(count(mesh)<=12000,key+" stays below 12k triangles")
		check(mesh.get_surface_count()<=4,key+" stays within four draw surfaces")
		var images: Dictionary={}
		for i in mesh.get_surface_count():
			var mat: StandardMaterial3D=mesh.surface_get_material(i)
			check(mat.albedo_texture!=null and mat.albedo_texture.get_image().has_mipmaps(),key+" surface "+str(i)+" texture has mipmaps")
			images[mat.albedo_texture.resource_path]=true
		check(images.has("res://deathmatch/weapons/tribes/armour-suit.res") and images.has("res://deathmatch/weapons/tribes/armour-finish.res"),key+" preserves separate suit and plate textures")
		check(asset.get_meta("undersuit_author","")=="KEIV" and asset.get_meta("asset_sources","").ends_with("SOURCES.md"),key+" retains donor attribution")
		asset.free()
func run():
	for directory in ["res://test-results/tribes-arsenal/","res://test-results/tribes-armour-family/","res://test-results/tribes-heavy-iteration/",output_dir]:
		DirAccess.make_dir_recursive_absolute(directory)
	check_assets()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):test_hash=arg;break
	var stage:=Stage.new();root.add_child(stage)
	var library=preload("res://deathmatch/avatars/library.gd").new();root.add_child(library)
	if FileAccess.file_exists(test_hash):
		test_hash=library.register_file(test_hash,false)
		check(not test_hash.is_empty(),"External candidate passes production avatar limits: "+library.last_error)
		if test_hash.is_empty():quit(1);return
		output_dir="res://test-results/tribes-arsenal/vroid-inspection/"
		DirAccess.make_dir_recursive_absolute(output_dir)
	if not test_hash.is_empty():output_key=String(library.entries[test_hash].path).get_file().get_basename()
	check(library.entries.size()>=3,"Three bundled VRMs available for compatibility checks")
	for variant in 2:
		for level in 3:
			var armour: String=["light","medium","heavy"][level]
			var id:=variant*3+level+1
			var actor=preload("res://deathmatch/fighter.gd").new();stage.add_child(actor);actor.setup(id,armour,Color.WHITE);actor.set_process(false);actor.set_physics_process(false)
			if not actor.avatar:
				actor.avatar=preload("res://deathmatch/art.gd").marine(Color.WHITE);actor.add_child(actor.avatar)
			if variant==1:
				var hash: String=test_hash if not test_hash.is_empty() else library.entries.keys()[level];actor.set_avatar(library.create_avatar(hash),hash)
			actor.show_alive(true,false);actor.tribes_state=actor.Tribes.fresh(armour)
			actor.position=Vector3((level-1)*1.85,0,variant*2.7)
			stage.players[id]={"team":level%2};actors.append(actor)
			var replacement:=Replacement.new();actor.add_child(replacement);replacement.update(actor);bodies.append(replacement)
			check(replacement.body!=null and count(replacement.body.mesh)>4000,armour+" creates skinned body on "+("VRM" if variant else "fallback"))
			var original_skin: Skin=replacement.body.skin
			for binding in original_skin.get_bind_count():
				var sk: Skeleton3D=actor.avatar.skeleton if variant else replacement.source_sk
				var name_here:=original_skin.get_bind_name(binding)
				var bone:=sk.find_bone(name_here) if not name_here.is_empty() else original_skin.get_bind_bone(binding)
				check(bone>=0 and bone<sk.get_bone_count(),armour+" bound "+sk.get_bone_name(bone))
			var material: Material
			for i in replacement.body.mesh.get_surface_count():
				var candidate=replacement.body.get_active_material(i)
				if candidate.resource_name.begins_with("Tribes Team Panels"):material=candidate;break
			check(material!=null and material.albedo_color!=Color.WHITE,armour+" has per-player team colour")
			var triangles:=count(replacement.body.mesh)
			if variant:
				var chest_frame:=ArmourVisual.avatar_chest(actor)
				var avatar_back: Vector3=actor.global_basis.inverse()*actor.avatar.global_basis.z
				check(chest_frame.basis.z.normalized().dot(avatar_back.normalized())>.95,armour+" backpack faces behind avatar despite imported skeleton axes")
				check(replacement.original_hands==["LeftHand","RightHand"],armour+" preserves both original avatar hands")
				check_cuffs(replacement,actor.avatar.skeleton,armour)
				var visible_heads:=0
				for m in actor.avatar.visual_meshes:
					if m.visible:
						visible_heads+=1
						check(count(m.mesh)<=count(m.get_meta("full_body_mesh")) and m.mesh.get_blend_shape_count()==m.get_meta("full_body_mesh").get_blend_shape_count(),"Retained original head mesh remains on original rig")
				check(visible_heads>0,armour+" original head remains visible")
				actor.show_alive(true,true);actor.set_local_body(true)
				check(count(replacement.body.mesh)<triangles,armour+" masks immediately with avatar first-person transition")
				replacement.update(actor)
				check(actor.avatar.visual_meshes.any(func(m):return m.visible and replacement.Original.has_hand(m.mesh,m.skin,actor.avatar.skeleton,"LeftHand")),armour+" original hand remains visible in first person")
				check(count(replacement.body.mesh)<triangles and count(replacement.body.mesh)>0,armour+" first-person torso mask leaves limbs")
				var mask_before: Mesh=replacement.body.mesh
				actor.avatar.set_keypad_glove("left")
				check(replacement.body.mesh==Mask.masked(replacement.body.get_meta("full_body_mesh"),replacement.body.skin,actor.avatar.skeleton,"left"),armour+" follows avatar hand-mask changes immediately")
				actor.avatar.set_keypad_glove("")
				check(replacement.body.mesh==mask_before,armour+" restores shared first-person mask after glove release")
				replacement.build(actor)
				check(actor.avatar.visual_meshes.count(replacement.body)==1 and count(replacement.body.mesh)<triangles,armour+" rebuilt body starts masked and registers only once")
				replacement.update(actor)
				var colour_before: Color=material.albedo_color
				stage.players[id].team=1-stage.players[id].team;replacement.update(actor)
				actor.set_local_body(false);actor.show_alive(true,false)
				check(count(replacement.body.mesh)==triangles,armour+" restores immediately with avatar third-person transition")
				replacement.update(actor)
				check(count(replacement.body.mesh)==triangles,armour+" third-person restores complete body")
				for i in replacement.body.mesh.get_surface_count():
					var candidate=replacement.body.get_active_material(i)
					if candidate.resource_name.begins_with("Tribes Team Panels"):check(candidate.albedo_color!=colour_before,armour+" changed team survives first-person transition")
				var previous: Array=[]
				for m in actor.avatar.visual_meshes:previous.append(m.get_meta("full_body_mesh"))
				replacement.clear()
				check(not actor.avatar.visual_meshes.any(func(m):return not is_instance_valid(m) or m.get_meta("tribes_body",false)),armour+" removes armour from avatar visibility lifecycle on unequip")
				for i in actor.avatar.visual_meshes.size():
					var m=actor.avatar.visual_meshes[i]
					check(m.mesh==previous[i] and m.visible==bool(m.get_meta("arena_third_person")),"Leaving Tribes restores original body and visibility")
				replacement.update(actor)
			else:
				check(actor.avatar.get_node("Upper/Head").get_child(0).visible,"Fallback original head is retained")
			for gun in actor.avatar.find_children("WeaponModel","Node3D",true,false):gun.hide()
			if is_instance_valid(actor.label):actor.label.hide()
	await process_frame;await process_frame
	for actor in actors:
		actor.avatar.set_process(false)
		if actor.avatar_hash.is_empty():actor.avatar.animate(0,Vector3.ZERO,"stand",1.65,true,{},false)
		else:
			if actor.avatar.gun:actor.avatar.gun.hide()
			if actor.avatar.offhand_gun:actor.avatar.offhand_gun.hide()
	for b in bodies:b.update(b.actor)
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(1600,1000)
		var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("17232b");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color("dde5ed");world.environment.ambient_light_energy=.65;stage.add_child(world)
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.6;stage.add_child(sun)
		var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(-15,150,0);rim.light_energy=.8;stage.add_child(rim)
		var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(2.2,3.3,-9);camera.look_at(Vector3(0,.85,1.2));camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.7
		for i in actors.size():
			var label:=Label3D.new();stage.add_child(label);label.text=("FALLBACK  /  " if i<3 else "VRM  /  ")+["LIGHT","MEDIUM","HEAVY"][i%3];label.position=actors[i].position+Vector3(0,-.15,0);label.font_size=28;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/tribes-arsenal/armour-gallery.png" if test_hash.is_empty() else output_dir+output_key+"-armour.png")
		if test_hash.is_empty():
			for label in stage.find_children("*","Label3D",true,false):label.hide()
			for i in 3:
				actors[i].hide();actors[i+3].position=Vector3((1-i)*1.7,0,0)
				var label:=Label3D.new();stage.add_child(label);label.text=["LIGHT","MEDIUM","HEAVY"][i];label.position=actors[i+3].position+Vector3(0,-.16,0);label.font_size=30;label.pixel_size=.004;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			camera.position=Vector3(0,1.05,-6);camera.look_at(Vector3(0,.90,0));camera.size=3.1
			for view in ["front","quarter","back"]:
				for i in range(3,6):actors[i].rotation.y={"front":0.0,"quarter":.55,"back":PI}[view]
				for i in 3:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/tribes-armour-family/"+view+".png")
			for i in range(3,5):
				actors[i].rotation.y=0
				camera.position=Vector3(actors[i].position.x,1.50,-6);camera.look_at(Vector3(actors[i].position.x,1.43,0));camera.size=.75
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/tribes-armour-family/"+["light","medium"][i-3]+"-collar.png")
			actors[3].hide();actors[4].hide()
			var gallery_labels: Array=[]
			for child in stage.get_children():
				if child is Label3D and child.visible:gallery_labels.append(child);child.hide()
			camera.position=Vector3(actors[5].position.x,1.03,-6);camera.look_at(Vector3(actors[5].position.x,.88,0));camera.size=2.12
			for view in ["front","quarter","side","back"]:
				actors[5].rotation.y={"front":0.0,"quarter":.55,"side":PI/2,"back":PI+.4}[view]
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/tribes-heavy-iteration/"+view+".png")
			# Same chest-space mounting used by armour_visual.gd, with the
			# actual interchangeable packs. Inspect shell/pack contact and vents.
			for pack_key in ["energy","ammo","repair","shield","jammer"]:
				var pack:=Models.model(pack_key+"_pack");actors[5].add_child(pack)
				pack.transform=ArmourVisual.avatar_chest(actors[5])*Transform3D(Basis.IDENTITY,Vector3(0,-.015,.29))
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/tribes-heavy-iteration/pack-"+pack_key+".png")
				pack.free()
			actors[3].show();actors[4].show()
			for label in gallery_labels:label.show()
			camera.position=Vector3(0,1.05,-6);camera.look_at(Vector3(0,.90,0));camera.size=3.1
			for first in [false,true]:
				for i in range(3,6):actors[i].rotation.y=0;actors[i].avatar.set_first_person(first)
				await process_frame;await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://test-results/st-armour-culling")
				root.get_texture().get_image().save_png("res://test-results/st-armour-culling/"+("first-person" if first else "third-person")+".png")
			for i in range(3,6):actors[i].avatar.set_first_person(false)
			for i in range(3,6):
				actors[i].rotation.y=.55;actors[i].avatar.stance="crouch";actors[i].avatar.collider_height=1.15;actors[i].avatar.set_process(true)
			for i in 35:await process_frame
			for i in range(3,6):
				actors[i].avatar.set_process(false)
				if actors[i].avatar.gun:actors[i].avatar.gun.hide()
				if actors[i].avatar.offhand_gun:actors[i].avatar.offhand_gun.hide()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/tribes-armour-family/crouch.png")
		if "--capture-wrists" in OS.get_cmdline_user_args():
			DirAccess.make_dir_recursive_absolute("res://test-results/st-hands-impacts")
			for i in range(3,6):
				var avatar=actors[i].avatar;avatar.set_process(false);avatar.solver.active=false
				var sk: Skeleton3D=avatar.skeleton;sk.reset_bone_poses()
				for side in ["Left","Right"]:
					var wrist:=sk.find_bone(side+"Hand");var rest:=sk.get_bone_global_rest(wrist)
					for reach in [0.0,.22]:
						var pose:=rest;pose.origin+=Vector3(reach,reach*.3,-reach*.4);pose.basis=Basis(Vector3.RIGHT,reach*4)*rest.basis
						sk.set_bone_global_pose(wrist,pose)
						var centre:=sk.to_global(pose.origin)
						camera.position=centre+Vector3(.15,.17,-.5);camera.look_at(centre);camera.size=.48
						await process_frame;await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://test-results/st-hands-impacts/%s-%s-%s.png"%[["light","medium","heavy"][i-3],side,str(reach)])
	var report:={"checks":checks,"failures":failures,"avatar":test_hash};FileAccess.open("res://test-results/tribes-arsenal/bodies.json" if test_hash.is_empty() else output_dir+output_key+"-armour.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRIBES_BODIES ",JSON.stringify(report));stage.free();library.free();quit(0 if failures.is_empty() else 1)
