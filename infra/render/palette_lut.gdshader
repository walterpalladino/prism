// Index -> color lookup shared by every layer sprite (GDD §9.4).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D index_tex : filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
uniform int transparent_index = 0;
uniform float layer_opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint = vec4(1.0);   // onion skin uses this

void fragment() {
	int idx = int(round(texture(index_tex, UV).r * 255.0));
	if (idx == transparent_index) {
		discard;
	}
	vec4 c = texelFetch(palette_tex, ivec2(idx, 0), 0);
	COLOR = vec4(c.rgb, c.a * layer_opacity) * tint;
}
