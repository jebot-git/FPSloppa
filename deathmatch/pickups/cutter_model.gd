extends Node3D
## Both complete handle/jaw arms pivot around the same fixed hinge.
const CYCLE:=.20
const CLOSE_TIME:=.045
const HOLD_TIME:=.06
var arms: Array[Node3D]=[]
var age:=CYCLE
func _init():
	name="DefuseCutters"
	var model=load("res://deathmatch/pickups/defusal/cutters.glb").instantiate();add_child(model)
	for key in ["DE_CutterLeft","DE_CutterRight"]:arms.append(model.find_child(key,true,false))
	pose(0.0);set_process(false)
func _ready():set_process(false)
func snip():
	age=0.0;pose(0.0);set_process(true)
func pose(amount: float):
	for i in arms.size():
		arms[i].rotation.y=(-1.0 if i==0 else 1.0)*lerpf(.24,-atan(.002/.069),clampf(amount,0,1))
func _process(delta: float):
	age=minf(CYCLE,age+delta)
	var amount:=smoothstep(0,CLOSE_TIME,age)*(1.0-smoothstep(CLOSE_TIME+HOLD_TIME,CYCLE,age))
	pose(amount)
	if age>=CYCLE:set_process(false)
