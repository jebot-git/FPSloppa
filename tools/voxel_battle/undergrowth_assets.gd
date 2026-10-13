extends RefCounted
## Opaque three-dimensional crowns nearby, fixed-Y cutout cards at far LOD.
## No physics bodies/shapes are authored by these assets.
const Builder=preload("res://tools/streamed_heightfield/structures.gd").Builder
static func crown(b,center:Vector3,radius:Vector3,segments:int,color:Color) -> void:
	for ring in 4:
		var y0:float=-PI*.5+PI*ring/4;var y1:float=-PI*.5+PI*(ring+1)/4
		for i in segments:
			var a:=TAU*i/segments;var c:=TAU*(i+1)/segments
			var points:=[center+Vector3(cos(y0)*cos(a),sin(y0),cos(y0)*sin(a))*radius,center+Vector3(cos(y0)*cos(c),sin(y0),cos(y0)*sin(c))*radius,center+Vector3(cos(y1)*cos(a),sin(y1),cos(y1)*sin(a))*radius,center+Vector3(cos(y1)*cos(c),sin(y1),cos(y1)*sin(c))*radius]
			for tri in [[0,2,1],[1,2,3]]:
				var start:int=b.vertices.size();var normal:Vector3=(points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]).normalized()
				var shade:Color=color*(.70+.30*absf(normal.dot(Vector3(-.4,.8,.3).normalized())));shade.a=1
				for index in tri:b.vertices.append(points[index]);b.colors.append(shade)
				b.indices.append_array(PackedInt32Array([start,start+1,start+2]))
static func leaves(b,kind:int,lod:int) -> void:
	var count:int=([18,10] if lod==0 else [8,6])[kind]
	var segments:int=3 if lod==0 else 2
	for i in count:
		var angle:float=i*2.399963+(kind*.57)
		var direction:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-sin(angle),0,cos(angle))
		var height:float=1.06+(.26 if kind==0 else .14)*(.5+.5*sin(i*3.7))
		var spread:float=.62+(.20 if kind==0 else .33)*(.5+.5*cos(i*2.1))
		var base_radius:float=.68 if kind==0 else .52
		var width:float=.23 if kind==0 else .26
		var color:=Color(.26,.40,.13).lightened((i%4)*.018) if kind==0 else Color(.17,.34,.14).lightened((i%3)*.02)
		for segment in segments:
			var start:int=b.vertices.size()
			for edge in [segment,segment+1]:
				var t:float=float(edge)/segments
				var center:=direction*(base_radius*(1.0-t*.30)+spread*t*t)+Vector3(0,.035+height*sin(t*PI*.5),0)
				var w:float=width*(1.0-t*.94)
				for sign_value in [-1,1]:b.vertices.append(center+side*w*sign_value);b.colors.append(color)
			b.indices.append_array(PackedInt32Array([start,start+2,start+1,start+1,start+2,start+3]))
static func asset(kind:int,lod:int) -> ArrayMesh:
	var b:=Builder.new()
	if kind<2:
		b.box(Vector3(0,.26,0),Vector3(.04,.52,.04),Color(.22,.28,.09));leaves(b,kind,lod)
	else:
		var color:=Color(.24,.40,.16) if kind==2 else Color(.17,.32,.12)
		var center:=Vector3(0,.92,0) if kind==2 else Vector3(.12,.96,-.1)
		var radius:=Vector3(1.03,.76,.86) if kind==2 else Vector3(.83,.87,1.15)
		b.box(Vector3(0,.42,0),Vector3(.06,.84,.06),Color(.24,.24,.09))
		if lod==0:
			crown(b,center,radius,6,color)
			for i in 3:
				var angle:=TAU*i/3+.3+kind*.5
				crown(b,center+Vector3(cos(angle)*radius.x*.63,-.12,sin(angle)*radius.z*.63),radius*.72,5,color.lightened(i*.025))
		else:crown(b,center,radius*Vector3(1.25,1,1.25),4,color)
	return b.finish()
static func card(kind:int) -> ArrayMesh:
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1.8,0,0),Vector3(1.8,0,0),Vector3(1.8,2.4,0),Vector3(-1.8,2.4,0)])
	var u:float=kind*.25
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(u,1),Vector2(u+.25,1),Vector2(u+.25,0),Vector2(u,0)])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,0,3,2])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.albedo_texture=load("res://experimental-assets/jungle/undergrowth.png")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold=.45;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.billboard_keep_scale=true
	mesh.surface_set_material(0,material);return mesh
