extends SceneTree
const Schedule=preload("res://tools/voxel_battle/weather_schedule.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<20:failures.append(label);push_error(label)
func _initialize()->void:
 check(Schedule.native_enabled(),"Native weather capability available")
 for seed_value in [0,1,42,13579,2147483647]:
  for i in range(-20,18000,7):
   var seconds:=i*.63
   var a:=Schedule.sample(seed_value,seconds);var b:=Schedule.sample_reference(seed_value,seconds)
   check(a.mode==b.mode and a.previous==b.previous and a.opportunity==b.opportunity and is_equal_approx(a.blend,b.blend) and a.target.is_equal_approx(b.target) and a.values.is_equal_approx(b.values),"Schedule parity %d %.3f"%[seed_value,seconds])
   var strike:=Schedule.lightning(seed_value,seconds);var reference:=Schedule.lightning_reference(seed_value,seconds)
   check(strike==reference,"Lightning parity %d %.3f"%[seed_value,seconds])
  var offset:=Schedule.change_offset(seed_value)
  for day in 7:
   for phase in [-.001,0.,.001,.045,.21,44.999,45.,45.001,1199.999,1200.]:
    var seconds:float=offset+day*1200.+phase
    var a:=Schedule.sample(seed_value,seconds);var b:=Schedule.sample_reference(seed_value,seconds)
    check(a.values.is_equal_approx(b.values) and a.opportunity==b.opportunity and is_equal_approx(a.blend,b.blend),"Transition boundary parity")
 print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures}));quit(0 if failures.is_empty() else 1)
