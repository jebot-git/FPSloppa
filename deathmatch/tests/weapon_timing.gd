extends SceneTree
const Timing=preload("res://deathmatch/network/weapon_timing.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label)
func _initialize():
 var rates:Array=[]
 for hz in [60,72,90,120]:
  for cycle in [.06,.066,.075,.086,.0875,.0955,.1,.114,.12,.225,.4,.5,.57,.7,.8,1.,1.63]:
   var old_cooldown:=0.;var old_count:=0
   var cooldown:=0.0;var count:=0;var now:=0.0;var last:=-1.0
   for tick in hz*30:
    if old_cooldown<=0:old_count+=1;old_cooldown=cycle
    old_cooldown=maxf(0,old_cooldown-1.0/hz)
    if cooldown<=0:
     count+=1;check(last<0 or now-last>=cycle-1.0/hz-.000001,"No compressed burst %s/%s"%[hz,cycle]);last=now
     cooldown=Timing.restart(cooldown,cycle)
    cooldown=Timing.advance(cooldown,1.0/hz,true);now+=1.0/hz
   if hz==60:rates.append({"cycle":cycle,"old_shots":old_count,"new_shots":count})
   check(absf(count-30.0/cycle)<=1.01,"Configured rate at %s Hz, %s cycle (shots %s)"%[hz,cycle,count])
 var idle:=Timing.advance(0.,10.,false)
 check(idle==0.0 and Timing.restart(idle,.1)==.1,"Idle time creates no catch-up debt")
 print("WEAPON_TIMING_RESULT ",JSON.stringify({"failures":failures,"thirty_second_rates":rates}));quit(0 if failures.is_empty() else 1)
