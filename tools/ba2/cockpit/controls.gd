extends RefCounted
## Input/heat simulation independent of rendering and tracking APIs.
const LIMIT=Vector2(0.0,4.0)
const SLEW_DEGREES:=7.5
const CYCLE:=.14
var aim:=Vector2.ZERO
var heat: Array[float]=[0.0,0.0]
var locked: Array[bool]=[false,false]
var cooldown: Array[float]=[0.0,0.0]
var since_shot: Array[float]=[10.0,10.0]
var shots: Array[int]=[0,0]
func step(delta: float,input: Vector2,fire: Array,enabled: bool=true) -> Array:
	var dt:=clampf(delta,0,.1)
	if not input.is_finite():input=Vector2.ZERO
	if enabled:aim=(aim+Vector2(0,clampf(input.y,-1,1))*SLEW_DEGREES*dt).clamp(-LIMIT,LIMIT)
	var fired: Array=[]
	for side in 2:
		cooldown[side]=maxf(0,cooldown[side]-dt);since_shot[side]+=dt
		if since_shot[side]>.25:heat[side]=maxf(0,heat[side]-.20*dt)
		var pressed: bool=enabled and side<fire.size() and fire[side]==true
		if locked[side] and heat[side]<=.35 and not pressed:locked[side]=false
		if not pressed or locked[side] or cooldown[side]>0:continue
		heat[side]=minf(1.0,heat[side]+.13);cooldown[side]=CYCLE;since_shot[side]=0
		locked[side]=heat[side]>=1.0;shots[side]+=1;fired.append(side)
	return fired
