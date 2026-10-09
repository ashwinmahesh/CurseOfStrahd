shader_type canvas_item;
// The big d20's picture (ui/dice/d20_die.gd) fades out toward its edges, so a die flying in from outside it never shows
// where the picture is cut off.
uniform float feather : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 e = min(UV, 1.0 - UV);
	COLOR = c * smoothstep(0.0, feather, min(e.x, e.y));
}
