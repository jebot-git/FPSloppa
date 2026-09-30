extends RefCounted
## Carry at most one tick of overshoot while held; never accumulate idle debt.
static func advance(value:float,delta:float,held:bool=true) -> float:
 var next:=value-delta
 if absf(next)<.0000001:return 0.0
 return maxf(-delta if held else 0.0,next)
static func restart(value:float,cycle:float) -> float:
 return maxf(cycle*.5,cycle+minf(value,0.0))
