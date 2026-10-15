extends RefCounted
## One deterministic description shared by geometry, offline irradiance and NVG glare.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
static func source(kind:int,p:Vector3,type:String,radius:float,power:float) -> Dictionary:
	return {"kind":kind,"local":p,"type":type,"radius":radius,"power":power}
static func rows(buildings:Array) -> Array:
	var result:Array=[]
	for building in buildings:
		var p:Vector3=building.center;var size:Vector2=building.size;var kind:int=building.kind
		for floor_index in building.floors:
			for x in [-.22,.22]:
				for z in [-.24,.24]:
					var at:=Vector3(size.x*x,floor_index*3.6+3.1,size.y*z)
					# An intermediate ceiling has an open stairwell on its right.
					# Mount the pendant on the intact slab instead of empty air.
					if floor_index<building.floors-1 and at.x>size.x*.5-4.4 and at.z<10.2-size.y*.5:
						at.x=size.x*.5-5.0
					result.append(source(kind,p+at,"hanging",18,.85))
		for side in [-1,1]:
			var row:=source(kind,p+Vector3(0,3.23,side*(size.y/2+2.3)),"entry",14,1.2)
			row["side"]=side;result.append(row)
	for kind in 11:
		# Posts stand on the verges, outside the 14 m wide gate/road corridor.
		for x in [-9.0,9.0]:
			for z in [-40.0,40.0]:
				var row:=source(kind,Vector3(x,4.8,z),"lamppost",17,.65)
				row["side"]=signf(x);result.append(row)
		for x in [-36.0,36.0]:
			for z in [-8.0,8.0]:
				var row:=source(kind,Vector3(signf(x)*46 if kind==1 else x,6.5,z),"floodlight",23,1.1)
				row["side"]=signf(z);result.append(row)
	# Dock lighting belongs to the raised dock, never the sea-bed heightfield.
	for x in [-49.0,49.0]:
		for z in [78.0,110.0]:result.append(source(2,Vector3(x,4.8,z),"lamppost",17,.65))
	return result
static func ground(row:Dictionary) -> float:
	if row.type in ["hanging","entry"] or (row.kind==2 and row.local.z>60):return 0.0
	var p:Vector3=Landscape.CENTERS[row.kind]+row.local
	return Landscape.surface(p.x,p.z).x-Landscape.CENTERS[row.kind].y
static func decorate(architecture) -> void:
	var metal:=Color(.24,.28,.25)
	for row in rows(architecture.specifications()):
		if row.kind!=architecture.kind:continue
		var p:Vector3=row.local;p.y+=ground(row)
		if row.type=="hanging":
			if architecture.level>0:continue
			architecture.box(p+Vector3(0,.25,0),Vector3(.035,.5,.035),metal,false)
			architecture.box(p+Vector3(0,.07,0),Vector3(.6,.14,.6),metal,false)
		elif row.type=="entry":
			if architecture.level==2:continue
			architecture.box(p+Vector3(0,.10,-row.side*1.15),Vector3(.08,.12,2.4),metal,false)
			architecture.box(p+Vector3(0,.08,0),Vector3(.65,.16,.4),metal,false)
		else:
			var height:float=4.8 if row.type=="lamppost" else 6.5
			var side:float=row.get("side",1.0)
			var offset:=Vector3(side*.9,0,0) if row.type=="lamppost" else Vector3(0,0,side*.9)
			architecture.box(p+offset-Vector3(0,height/2,0),Vector3(.16,height,.16),metal,false)
			architecture.box(p+offset-Vector3(0,height-.15,0),Vector3(.48,.3,.48),metal,false)
			if architecture.level<2:
				architecture.box(p+offset*.5+Vector3(0,.12,0),Vector3(1.1,.12,.12) if row.type=="lamppost" else Vector3(.12,.12,1.1),metal,false)
			architecture.box(p+Vector3(0,.09,0),Vector3(.7,.18,.45) if row.type=="lamppost" else Vector3(1.25,.22,.7),metal,false)
