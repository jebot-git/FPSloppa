extends RefCounted
## Cosmetic preset approximation, not a determination of the wearer's emotional state.
static func pair(face: XRFaceTracker,left: int,right: int) -> float:
	var a:=face.get_blend_shape(left);var b:=face.get_blend_shape(right)
	return clampf((a+b)*.5,0,1) if is_finite(a) and is_finite(b) else 0.0
static func sample(face: XRFaceTracker) -> PackedFloat32Array:
	var smile:=maxf(pair(face,XRFaceTracker.FT_MOUTH_SMILE_LEFT,XRFaceTracker.FT_MOUTH_SMILE_RIGHT),pair(face,XRFaceTracker.FT_MOUTH_CORNER_PULL_LEFT,XRFaceTracker.FT_MOUTH_CORNER_PULL_RIGHT))
	var frown:=pair(face,XRFaceTracker.FT_MOUTH_FROWN_LEFT,XRFaceTracker.FT_MOUTH_FROWN_RIGHT)
	var lower:=pair(face,XRFaceTracker.FT_BROW_LOWERER_LEFT,XRFaceTracker.FT_BROW_LOWERER_RIGHT)
	var inner:=pair(face,XRFaceTracker.FT_BROW_INNER_UP_LEFT,XRFaceTracker.FT_BROW_INNER_UP_RIGHT)
	var outer:=pair(face,XRFaceTracker.FT_BROW_OUTER_UP_LEFT,XRFaceTracker.FT_BROW_OUTER_UP_RIGHT)
	var wide:=pair(face,XRFaceTracker.FT_EYE_WIDE_LEFT,XRFaceTracker.FT_EYE_WIDE_RIGHT)
	var jaw: float=face.get_blend_shape(XRFaceTracker.FT_JAW_OPEN)
	jaw=clampf(jaw,0,1) if is_finite(jaw) else 0.0
	return classify(smile,frown,lower,inner,outer,wide,jaw)
static func classify(smile: float,frown: float,lower: float,inner: float,outer: float,wide: float,jaw: float) -> PackedFloat32Array:
	# Strong smile; lowered brows; worried brows + frown; soft smile; wide eyes + raised brows.
	var scores: Array[float]=[maxf(0,smile-.25)*1.4*(1-frown),lower*(1-.7*inner),minf(frown,inner)*1.4,smile*(1-smile)*2*(1-lower)*(1-wide)*(1-jaw),minf(wide,maxf(inner,outer))*.8+minf(wide,jaw)*.4]
	var best:=-1;var strength:=.22
	for i in 5:
		if is_finite(scores[i]) and scores[i]>strength:best=i;strength=scores[i]
	var result:=PackedFloat32Array([0,0,0,0,0])
	if best>=0:result[best]=clampf((strength-.15)/.85,0,1)
	return result
