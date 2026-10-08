extends SceneTree
const Smooth=preload("res://deathmatch/bot_ai/travel_smoothing.gd")
func _initialize():
 var previous:=Vector3.FORWARD;var raw_previous:=previous;var raw:=0.;var filtered:=0.
 for i in 120:
  var wish:=Vector3(.25 if i%2==0 else -.25,0,-1).normalized()
  var result:=Smooth.filtered(previous,wish,1./60)
  raw+=raw_previous.angle_to(wish);filtered+=previous.angle_to(result);previous=result;raw_previous=wish
 var failures: Array=[]
 if filtered>=raw*.3:failures.append("Small correction jitter not reduced")
 if Smooth.filtered(previous,Vector3.ZERO,1./60)!=Vector3.ZERO:failures.append("Stop delayed")
 if not Smooth.filtered(Vector3.FORWARD,Vector3.BACK,1./60).is_equal_approx(Vector3.BACK):failures.append("Reversal delayed")
 var result={"raw_turn":raw,"smoothed_turn":filtered,"reduction":1-filtered/raw,"failures":failures}
 FileAccess.open("res://tools/de_penetration/travel-smoothing.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("TRAVEL_SMOOTHING_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
