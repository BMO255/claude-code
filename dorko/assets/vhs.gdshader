shader_type canvas_item;
// The "VHS dream" filter: subtle chromatic aberration, vignette, scanlines,
// and a slow shimmer. Kept gentle; toggled from Options.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float aberration : hint_range(0.0, 0.01) = 0.0016;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.36;
uniform float scanline_strength : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	vec2 uv = SCREEN_UV;
	float r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;
	vec3 col = vec3(r, g, b);
	float d = distance(uv, vec2(0.5, 0.5));
	col *= 1.0 - vignette_strength * smoothstep(0.3, 0.78, d);
	col *= 1.0 - scanline_strength * step(0.5, fract(uv.y * 180.0));
	float shimmer = sin(TIME * 0.7 + uv.y * 40.0) * 0.5 + 0.5;
	col *= 1.0 - 0.02 * shimmer;
	COLOR = vec4(col, 1.0);
}
