shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float diameter_moa=4.0;
varying vec3 lens_point;
void vertex() {lens_point=VERTEX;}
void fragment() {
 vec3 eye=(inverse(MODEL_MATRIX)*INV_VIEW_MATRIX*vec4(EYE_OFFSET,1.0)).xyz;
 vec3 ray=normalize(lens_point-eye);
 // A collimated reticle is a direction at infinity, clipped by the physical
 // lens quad. Moving the eye moves its intersection on glass, not its aim.
 if(eye.z<=0.0 || ray.z>=0.0)discard;
 float angle=length(ray.xy)/max(-ray.z,.0001);
 float radius=tan(radians(diameter_moa/60.0)*.5);
 float edge=max(fwidth(angle),radius*.15);
 float coverage=1.0-smoothstep(radius-edge,radius+edge,angle);
 if(coverage<.001)discard;
 ALBEDO=vec3(1.0,.015,.005);EMISSION=ALBEDO*1.5;
 ALPHA=coverage;
}
