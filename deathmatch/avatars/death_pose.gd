extends RefCounted
## Authored, bounded collapse in avatar metres. No bodies, joints or floor probes.
const SETTLE_TIME := .90
const VISIBLE_TIME := 2.5
static func sample(time: float, hip_height: float=.92) -> Dictionary:
	var buckle := smoothstep(0.0,.22,time)
	var fall := smoothstep(.18,.72,time)
	var settle := smoothstep(.72,SETTLE_TIME,time)
	var pelvis := Vector3(0,hip_height,0).lerp(Vector3(-.04,hip_height*.73,-.08),buckle)
	pelvis=pelvis.lerp(Vector3(.10,.25,.12),fall).lerp(Vector3(.10,.22,.12),settle)
	var tilt := Vector3(-.20,0,-.12)*buckle
	tilt=tilt.lerp(Vector3(PI*.48,.16,-.16),fall).lerp(Vector3(PI*.50,.20,-.12),settle)
	return {"pelvis":pelvis,"basis":Basis.from_euler(tilt),"release":smoothstep(.08,.70,time),
		"left_foot":Vector3(-.32,.12,-.63),"right_foot":Vector3(.38,.12,-.38),
		"left_knee":Vector3(-.36,.32,-.30),"right_knee":Vector3(.48,.43,-.04),
		"left_hand":Vector3(-.64,.13,.26),"right_hand":Vector3(.62,.13,.75),
		"left_elbow":Vector3(-.68,.18,.63),"right_elbow":Vector3(.52,.20,.40)}
