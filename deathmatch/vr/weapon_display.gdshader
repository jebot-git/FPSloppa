shader_type spatial;
render_mode unshaded;
uniform sampler2D readout : source_color, filter_linear;
void fragment() { ALBEDO=texture(readout,UV).rgb; }
