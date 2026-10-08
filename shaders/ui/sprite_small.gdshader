// A character sheet drawn far smaller than it was rendered (the title screen's travellers, some 30 px tall from a
// 768 px cell). Sheets carry no mipmaps (the 3D sprites sample them full size, sprite_crisp.gdshader), so plain
// sampling would skip most texels and shimmer: this averages a 6x6 grid over each screen pixel's footprint.
shader_type canvas_item;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 6; i++) {
		for (int j = 0; j < 6; j++) {
			vec2 o = (vec2(float(i), float(j)) + 0.5) / 6.0 - 0.5;
			vec4 s = texture(TEXTURE, UV + dx * o.x + dy * o.y);
			acc += vec4(s.rgb * s.a, s.a);
		}
	}
	acc /= 36.0;
	COLOR = vec4(acc.a > 0.0 ? acc.rgb / acc.a : vec3(0.0), acc.a) * tint;
}
