extends RefCounted
## Original low-poly arena banners. Cloth and emblem share the same gentle wind deformation.
const COLORS=[Color("b83d32"),Color("3c70b0")]
static func create(team: int) -> Node3D:
	var root:=Node3D.new();root.name="Banner"
	var art=preload("res://deathmatch/art.gd")
	var iron:=art.material(Color("393a36"),.65)
	var brass:=art.material(Color("a48a53"),.6)
	cylinder(root,.045,.045,1.9,Vector3(0,.95,0),iron)
	for y in [.10,.30,1.22,1.82]:cylinder(root,.071,.071,.055,Vector3(0,y,0),brass)
	cylinder(root,0,.095,.23,Vector3(0,2.015,0),brass)
	# An angular socket and four stabilizing feet make a grounded pedestal silhouette.
	cylinder(root,.13,.24,.12,Vector3(0,.06,0),iron,8)
	for i in range(4):
		var foot:=art.box(root,Vector3.ZERO,Vector3(.32,.055,.095),iron)
		foot.rotation.y=i*PI*.5;foot.position=Vector3(cos(i*PI*.5)*.13,.025,sin(i*PI*.5)*.13)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint:Color=COLORS[team]
	for x in range(10):
		for y in range(6):
			var a:=cloth_point(x,y);var b:=cloth_point(x+1,y);var c:=cloth_point(x+1,y+1);var d:=cloth_point(x,y+1)
			var color:Color=Color("c2a873") if y==0 or y==5 else tint.lightened(.06 if x%2==0 else 0)
			quad(st,a,b,c,d,color)
	# Ivory lightning bolt / split chevron distinguish teams even without colour.
	var emblem: Array=[Vector2(.53,1.76),Vector2(.35,1.53),Vector2(.49,1.53),Vector2(.42,1.31),Vector2(.69,1.61),Vector2(.55,1.61)] if team==0 else [Vector2(.33,1.68),Vector2(.46,1.68),Vector2(.59,1.48),Vector2(.72,1.68),Vector2(.84,1.68),Vector2(.59,1.31)]
	var polygon:=PackedVector2Array(emblem);var triangles:=Geometry2D.triangulate_polygon(polygon)
	for side in [-1,1]:
		for i in triangles:
			st.set_color(Color("f0ddb1"));st.set_normal(Vector3(0,0,side));st.add_vertex(Vector3(polygon[i].x,polygon[i].y,side*.008))
	var mesh:=MeshInstance3D.new();mesh.name="Cloth";mesh.mesh=st.commit()
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode cull_disabled;
void vertex() {
 float reach = max(0.0, VERTEX.x - 0.05);
 VERTEX.z += sin(TIME * 2.1 - VERTEX.x * 7.0 + VERTEX.y * 1.4) * 0.065 * reach;
 VERTEX.z += sin(VERTEX.x * 9.0) * 0.025;
}
void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 0.94; }
"""
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material;root.add_child(mesh)
	return root
static func cloth_point(x: int,y: int) -> Vector3:
	var across:=x/10.0;var down:=y/6.0
	# A swallow-tail fly edge; the top and bottom retain a narrow brass-coloured hem.
	var width:=.96-.14*sin(down*PI)
	return Vector3(.05+across*width,1.85-down*.68,0)
static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	for v in [a,b,c,a,c,d]:st.set_color(color);st.set_normal(Vector3.FORWARD);st.add_vertex(v)
static func cylinder(parent: Node3D,top: float,bottom: float,height: float,pos: Vector3,material: Material,sides: int=12) -> void:
	var mesh:=CylinderMesh.new();mesh.top_radius=top;mesh.bottom_radius=bottom;mesh.height=height;mesh.radial_segments=sides;mesh.rings=1
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.position=pos;parent.add_child(node)
