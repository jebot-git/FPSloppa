extends RefCounted
const Art=preload("res://deathmatch/art.gd")
static func make(kind: String,team: int) -> Node3D:
	var root:=Node3D.new();var dark=Art.material(Color("303944"),.65);var steel=Art.material(Color("778794"),.7)
	var paint=Art.material(Color("b84334") if team==0 else Color("326faa"),.5)
	Art.box(root,Vector3(0,.35,0),Vector3(3,.7,3),dark);Art.box(root,Vector3(0,1,0),Vector3(1.8,.8,1.8),paint)
	var head:=Node3D.new();head.name="Head";head.position.y=2.25;root.add_child(head)
	Art.box(head,Vector3.ZERO,Vector3(2.5,1,1.9),paint)
	for x in [-1.12,1.12]:
		Art.box(head,Vector3(x,.04,.38),Vector3(.16,.72,.75),steel)
		for y in [-.2,0,.2]:Art.box(head,Vector3(x*1.08,y,.4),Vector3(.05,.06,.6),dark)
	Art.box(head,Vector3(0,.2,-.98),Vector3(.3,.25,.08),Art.material(Color("73d4d8"),.3,.8))
	if kind=="missile":
		for x in [-.8,.8]:
			Art.box(head,Vector3(x,0,-.4),Vector3(.7,1.1,2.2),steel)
			for y in [-.25,.25]:Art.box(head,Vector3(x,y,-1.52),Vector3(.4,.3,.04),dark)
	elif kind=="mortar":
		Art.barrel(head,Vector3(0,.05,-1),.65,2.6,steel);Art.barrel(head,Vector3(0,.05,-2.32),.48,.04,dark)
		Art.barrel(head,Vector3(0,.05,-1.8),.73,.24,dark)
	elif kind=="elf":
		Art.box(head,Vector3(0,.1,-1),Vector3(.8,.8,1.8),dark)
		for x in [-.7,.7]:
			Art.box(head,Vector3(x,0,-1.3),Vector3(.25,.35,2.0),steel)
			Art.box(head,Vector3(x,.18,-2.2),Vector3(.32,.4,.3),Art.material(Color("79b5eb"),.5,.6))
		for z in [-.5,-.8,-1.1,-1.4]:Art.box(head,Vector3(0,.1,z),Vector3(1,.95,.1),steel)
	else:
		for x in [-.58,.58]:
			Art.barrel(head,Vector3(x,0,-1),.27,2.4,steel);Art.barrel(head,Vector3(x,0,-2.22),.19,.04,dark)
			Art.barrel(head,Vector3(x,0,-1.65),.34,.3,dark)
	var label:=Label3D.new();label.name="Status";label.font_size=24;label.pixel_size=.012;label.position.y=3.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;root.add_child(label)
	if kind=="mini":root.scale=Vector3.ONE*.57
	return root
