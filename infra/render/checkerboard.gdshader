// Transparency checkerboard behind the canvas. Cells are sized in screen pixels.
shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.227, 0.227, 0.267, 1.0);
uniform vec4 color_b : source_color = vec4(0.267, 0.267, 0.31, 1.0);
uniform vec2 canvas_size = vec2(64.0);
uniform float zoom = 1.0;
uniform float cell_px = 8.0;

void fragment() {
	vec2 cell = floor(UV * canvas_size * zoom / cell_px);
	COLOR = mod(cell.x + cell.y, 2.0) < 1.0 ? color_a : color_b;
}
