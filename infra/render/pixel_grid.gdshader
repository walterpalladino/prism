// Pixel grid and optional tile grid over the canvas; lines are one screen pixel wide.
shader_type canvas_item;

uniform vec2 canvas_size = vec2(64.0);
uniform float zoom = 1.0;
uniform bool pixel_grid = true;
uniform float tile = 0.0;
uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.2);
uniform vec4 tile_color : source_color = vec4(0.239, 0.482, 1.0, 0.55);

void fragment() {
	vec2 p = UV * canvas_size;
	float line = 1.0 / zoom;
	vec4 c = vec4(0.0);
	if (pixel_grid) {
		vec2 f = fract(p);
		if (f.x < line || f.y < line) {
			c = grid_color;
		}
	}
	if (tile > 0.0) {
		vec2 t = mod(p, tile);
		if (t.x < line || t.y < line) {
			c = tile_color;
		}
	}
	if (c.a == 0.0) {
		discard;
	}
	COLOR = c;
}
