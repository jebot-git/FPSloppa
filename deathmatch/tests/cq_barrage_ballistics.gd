extends SceneTree
const Tanks=preload("res://deathmatch/conquest/classes/battery_tank.gd")
var failures:Array=[]
var cases:=0
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);print("FAIL ",label)
func run() -> void:
	for elevation in [-30.0,0.0,40.0]:
		for pitch in [.15,.5,.785,1.1]:
			for motion in [Vector3.ZERO,Vector3(4,0,-5)]:
				var origin:=Vector3(20,50,-10)
				var nominal:Vector3=Vector3(0,sin(pitch),-cos(pitch))*Tanks.SPEED+motion
				var time:float=(nominal.y+sqrt(nominal.y*nominal.y+2*Tanks.GRAVITY*(origin.y-elevation)))/Tanks.GRAVITY
				var center:Vector3=origin+nominal*time-Vector3.UP*Tanks.GRAVITY*time*time*.5
				for shot in 8:
					var offset:=Vector3(cos(shot*TAU/8),0,sin(shot*TAU/8))*Tanks.BARRAGE_RADIUS
					var solution:=Tanks.barrage_solution(origin,center,time,motion,offset)
					var end:Vector3=origin+solution.velocity*solution.time-Vector3.UP*Tanks.GRAVITY*solution.time*solution.time*.5
					check(end.distance_to(solution.target)<.02,"Ballistic endpoint %s"%cases)
					check(solution.target.distance_to(center)<=Tanks.BARRAGE_RADIUS+.01,"Bounded radius %s"%cases)
					check(solution.velocity.is_finite() and solution.time>0,"Finite moving/high/low arc %s"%cases)
					cases+=1
	# A vehicle changing position can put the frozen target beyond fixed-speed range.
	var unreachable:=Tanks.barrage_solution(Vector3(0,3,0),Vector3(0,0,-800),4,Vector3(5,0,0),Vector3(15,0,0))
	check(unreachable.velocity.is_finite() and unreachable.target.distance_to(Vector3(0,0,-800))<=15,"Unreachable fallback keeps bounded nonzero dispersion")
	check(unreachable.target.x>0,"Fallback does not collapse all shots onto center")
	print("CQ_BARRAGE_BALLISTICS_RESULT cases=",cases," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
