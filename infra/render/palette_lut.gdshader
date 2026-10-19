// Index -> color lookup shared by every layer sprite (GDD §9.4).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D index_tex : filter_nearest;
uniform sampler2D palette_tex : filter_nearest;
uniform int transparent_index = 0;
uniform float layer_opacity : hint_range(0.0, 1.0) = 1.0;
// Onion skin: rgb is the tint color, a is how strongly it replaces the palette color.
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	int idx = int(round(texture(index_tex, UV).r * 255.0));
	if (idx == transparent_index) {
		discard;
	}
	vec4 c = texelFetch(palette_tex, ivec2(idx, 0), 0);
	COLOR = vec4(mix(c.rgb, tint.rgb, tint.a), c.a * layer_opacity);
}
