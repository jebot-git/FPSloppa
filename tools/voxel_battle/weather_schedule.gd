extends RefCounted
## Stateless schedule: one opportunity every full lighting cycle, identical on late join.
const DAY_SECONDS:=1200.0
const TRANSITION_SECONDS:=45.0
const NAMES:=["Clear","Fog","Rain","Thunderstorm"]
# Exponential fog density, rainfall, overcast, thunder intensity.
const BASE_PROFILES:=[Vector4(.00012,0,0,0),Vector4(.006,0,.5,0),Vector4(.0018,.65,.8,0),Vector4(.0032,1,1,1)]
# Fog and rainfall are independent seeded targets, shared by every client.
const FOG_RANGES:=[Vector2(.00006,.00028),Vector2(.0025,.01),Vector2(.0007,.003),Vector2(.0014,.005)]
const RAIN_RANGES:=[Vector2.ZERO,Vector2.ZERO,Vector2(.25,.85),Vector2(.65,1.)]
static func hash_value(seed_value:int,index:int)->int:
 var n:=(seed_value ^ ((index+104729)*374761393))&0x7fffffff
 n=((n^(n>>13))*1274126177)&0x7fffffff
 return (n^(n>>16))&0x7fffffff
static func change_offset(seed_value:int)->float:return 120.0+float(hash_value(seed_value,0)%720)
static func mode_at(seed_value:int,index:int)->int:
 # Clear 40%, fog 20%, rain 25%, thunderstorm 15%; repeats are deliberate.
 var roll:=hash_value(seed_value,index+1)%100
 return 0 if roll<40 else 1 if roll<60 else 2 if roll<85 else 3
static func profile_at(seed_value:int,index:int)->Vector4:
 var mode:=mode_at(seed_value,index)
 var profile:Vector4=BASE_PROFILES[mode]
 var fog:float=float(hash_value(seed_value,index*3+200001)%65536)/65535.
 var rain:float=float(hash_value(seed_value,index*3+200002)%65536)/65535.
 profile.x=lerpf(FOG_RANGES[mode].x,FOG_RANGES[mode].y,fog)
 profile.y=lerpf(RAIN_RANGES[mode].x,RAIN_RANGES[mode].y,rain)
 return profile
static func native_enabled()->bool:
 return preload("res://deathmatch/native/runtime.gd").available("FPSWorld") and ClassDB.class_has_method("FPSWorld","weather_sample") and not OS.get_cmdline_user_args().has("--gdscript-weather")
static func sample(seed_value:int,seconds:float)->Dictionary:
 if native_enabled():return ClassDB.class_call_static("FPSWorld","weather_sample",seed_value,seconds)
 return sample_reference(seed_value,seconds)
static func sample_reference(seed_value:int,seconds:float)->Dictionary:
 var t:=maxf(0,seconds)-change_offset(seed_value)
 var index:=floori(t/DAY_SECONDS)
 var current:=mode_at(seed_value,index)
 var previous:=mode_at(seed_value,index-1) if index>=0 else current
 var blend:=smoothstep(0.,TRANSITION_SECONDS,fposmod(t,DAY_SECONDS)) if index>=0 else 1.
 var target:=profile_at(seed_value,index)
 var prior:=profile_at(seed_value,index-1) if index>=0 else target
 return {"mode":current,"previous":previous,"blend":blend,"opportunity":index,"target":target,"values":prior.lerp(target,blend)}
static func lightning(seed_value:int,seconds:float)->Dictionary:
 if native_enabled():return ClassDB.class_call_static("FPSWorld","weather_lightning",seed_value,seconds)
 return lightning_reference(seed_value,seconds)
static func lightning_reference(seed_value:int,seconds:float)->Dictionary:
 var index:=floori(maxf(0,seconds)/20.)
 var value:=hash_value(seed_value,index+500001)
 var strike_at:=index*20.+2.+float(value%8000)/1000.
 var age:=seconds-strike_at
 var flash:=maxf(0,1-absf(age-.045)/.045)+.6*maxf(0,1-absf(age-.21)/.09)
 return {"id":index,"at":strike_at,"flash":flash,"angle":float(value%6283)/1000.,"distance":250.+float(value%450)}
