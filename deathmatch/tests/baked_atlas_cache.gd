extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for id in ["as_hislop","as_frigate","as_hislop_tiny","as_frigate_tiny","dm_lasercade_slop","dm_auhdm2_slop"]:
		var scene=load("res://maps/cache/"+id+"-lightmap1.scn").instantiate()
		assert(scene.get_meta("baked_light_faces",0)>100)
		assert(scene.get_meta("baked_light_invalid_faces",0)==0 and scene.get_meta("baked_light_overflow_faces",0)==0)
		var found:=false
		for node in scene.find_children("*","MeshInstance3D",true,false):
			for i in node.mesh.get_surface_count():
				var material=node.mesh.surface_get_material(i)
				if not material is ShaderMaterial:continue
				var atlas=material.get_shader_parameter("bake_texture")
				if not atlas:continue
				var pixels: Image=atlas.get_image()
				var colours: Dictionary={}
				for y in range(2,mini(256,pixels.get_height()),3):
					for x in range(2,pixels.get_width(),17):colours[pixels.get_pixel(x,y).to_rgba32()]=true
				assert(colours.size()>10,"Saved lighting atlas must contain authored lighting, not the uniform initial fill")
				print("PASS ",id," saved atlas colours=",colours.size())
				found=true;break
			if found:break
		assert(found)
		scene.free()
	quit.call_deferred()
