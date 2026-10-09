// A new place resolving out of a soft blur as the black lifts (Visual Polish Plan 10; PlaceDissolve): the finished
// picture read back from the screen's mipmaps, softest at `amount` 1 and sharp at 0, a touch brighter while it's soft
// so the change reads as a haze clearing rather than a smear. Drawn on a canvas layer over the world and under the HUD,
// only while a place comes in.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// The softest blur, as a mip level at 1080 lines (one more for each doubling of the screen's height).
uniform float softest = 5.0;
uniform float lines = 1080.0;

void fragment() {
	float lod = amount * (softest + log2(max(lines, 1.0) / 1080.0));
	vec3 col = textureLod(screen, SCREEN_UV, lod).rgb;
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), 0.25 * amount) + vec3(0.04) * amount;
	COLOR = vec4(col, 1.0);
}
