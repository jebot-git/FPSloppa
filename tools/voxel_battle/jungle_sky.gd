extends RefCounted
## Authored analytic tropical sky radiance: identical source for skybox and bake.
const ROOT:="res://experimental-assets/jungle/lighting/"
const SUN_NOON:=Vector3(-.4,.8,.3)
const SUN_DUSK:=Vector3(-.95,.14,.28)
const SUN_DAWN:=Vector3(.95,.14,.28)
const STAGES:=["day","golden","dusk","twilight","night","dawn_twilight","dawn","morning"]
const KEYS:=[Vector2(0,0),Vector2(.20,0),Vector2(.24,1),Vector2(.29,2),Vector2(.33,3),Vector2(.36,4),Vector2(.64,4),Vector2(.67,5),Vector2(.71,6),Vector2(.76,7),Vector2(.80,0),Vector2(1,0)]
static var noise:FastNoiseLite
static func directions() -> Array[Vector3]:return [Vector3.UP,Vector3(.8,.6,0),Vector3(-.8,.6,0),Vector3(0,.6,.8),Vector3(0,.6,-.8)]
static func cycle_phase(seconds:float,cycle:float)->float:
	var p:=fposmod(seconds/cycle,1.0)
	if p<.275:return p*.31/.275
	if p<.725:return .31+(p-.275)*.375/.45
	return .685+(p-.725)*.315/.275
static func stage_pair(seconds:float,cycle:float) -> Vector3:
	var phase:=cycle_phase(seconds,cycle)
	for i in range(KEYS.size()-1):
		if phase<=KEYS[i+1].x:
			return Vector3(KEYS[i].y,KEYS[i+1].y,smoothstep(KEYS[i].x,KEYS[i+1].x,phase))
	return Vector3.ZERO
static func sun_weights(seconds:float,cycle:float) -> Vector3:
	var p:=cycle_phase(seconds,cycle)
	if p<.20:return Vector3(1,0,0)
	if p<.27:
		var t:=smoothstep(.20,.27,p);return Vector3(1-t,t,0)
	if p<.35:return Vector3(0,1-smoothstep(.27,.35,p),0)
	if p<.65:return Vector3.ZERO
	if p<.72:return Vector3(0,0,smoothstep(.65,.72,p))
	if p<.80:
		var t:=smoothstep(.72,.80,p);return Vector3(t,0,1-t)
	return Vector3(1,0,0)
static func radiance(direction:Vector3,stage:int) -> Color:
	if noise==null:
		noise=FastNoiseLite.new();noise.seed=62813;noise.frequency=1;noise.fractal_octaves=4
	var palettes=[
		[Color(.075,.26,.55),Color(.48,.68,.74)],
		[Color(.10,.21,.37),Color(.82,.48,.19)],
		[Color(.022,.048,.12),Color(.43,.14,.065)],
		[Color(.003,.009,.030),Color(.030,.021,.046)],
		[Color(.00045,.0008,.0016),Color(.0011,.0018,.0028)],
		[Color(.003,.010,.035),Color(.035,.027,.055)],
		[Color(.025,.065,.15),Color(.48,.22,.13)],
		[Color(.085,.25,.43),Color(.67,.51,.34)]]
	var up:=maxf(0,direction.y);var color:Color=palettes[stage][0].lerp(palettes[stage][1],pow(1-up,4))
	if direction.y<0:return palettes[stage][1]*.16
	var sunset:=stage in [1,2,3];var sunrise:=stage in [5,6,7]
	var sun:Vector3=(SUN_DUSK if sunset else SUN_DAWN if sunrise else SUN_NOON).normalized()
	var halo:=pow(maxf(0,direction.dot(sun)),24)
	if stage!=4:color+=Color(1,.56,.22)*halo*(.35 if sunset or sunrise else .1)
	var cloud:=smoothstep(-.06,.32,noise.get_noise_3dv(direction*4+Vector3(1,3,7))) * smoothstep(.015,.20,up)
	color=color.lerp(Color(.82,.84,.77) if stage==0 else palettes[stage][1]*.7,cloud*(.6 if stage<3 or stage>5 else .14))
	if stage in [0,1,2,6,7]:color+=Color(1,.83,.53)*smoothstep(.9996,.9999,direction.dot(sun))*.9
	if stage in [3,4,5]:
		var cell:=Vector3(floor(direction.x*850),floor(direction.y*850),floor(direction.z*850))
		var star:=fposmod(sin(cell.dot(Vector3(12.9898,78.233,37.719)))*43758.5453,1)
		if star>.9992:color+=Color(.10,.13,.18)*smoothstep(.1,.4,up)*(1 if stage==4 else .2)
		var moon:=Vector3(.35,.62,-.4).normalized();color+=Color(.30,.34,.37)*smoothstep(.9995,.9998,direction.dot(moon))*(1 if stage==4 else .12)
	color.a=1;return color
static func averages() -> Array:
	var result:Array=[]
	for stage in STAGES.size():
		var color:=Color(0,0,0,0)
		for direction in directions():color+=radiance(direction,stage)/5
		result.append([color.r,color.g,color.b])
	return result
static func bake() -> void:
	var atlas:=Image.create(4096,1024,false,Image.FORMAT_RGBA8)
	for stage in STAGES.size():
		var image:=Image.create(1024,512,false,Image.FORMAT_RGBA8)
		for y in 512:
			for x in 1024:
				var a:=TAU*(x+.5)/1024;var e:=PI*(y+.5)/512
				image.set_pixel(x,y,radiance(Vector3(sin(e)*sin(a),cos(e),-sin(e)*cos(a)),stage))
		atlas.blit_rect(image,Rect2i(0,0,1024,512),Vector2i(stage%4*1024,stage/4*512));print("SKY BAKE ",STAGES[stage])
	assert(atlas.save_png(ROOT+"skybox.png")==OK)
