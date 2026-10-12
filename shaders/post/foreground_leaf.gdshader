// A spray of leaves or fir right in front of the lens (Visual Polish Plan 11; ForegroundFraming): a leaf card from the
// plants' atlas drawn out of focus (a high mipmap: it's far nearer than anything the camera focuses on) and nearly black
// against the scene, with the faintest edge of the place's key light, so it frames the view like a branch the camera is
// looking past. Drawn on a canvas layer over the world and under the HUD.
shader_type canvas_item;
render_mode unshaded;

// How out of focus (a mipmap bias at 1080 lines), how dark, and the light along its edge.
uniform float blur = 3.2;
uniform vec3 shade : source_color = vec3(0.03, 0.03, 0.05);
uniform vec3 rim : source_color = vec3(0.4, 0.4, 0.5);
uniform float rim_amount = 0.25;
uniform float opacity = 0.0;

void fragment() {
	vec4 soft = texture(TEXTURE, UV, blur);
	vec4 softer = texture(TEXTURE, UV, blur + 1.5);
	// The edge: where the softer copy reaches past the soft one (light catching the leaves' outer fringe).
	float edge = clamp(softer.a - soft.a * 0.8, 0.0, 1.0);
	vec3 col = shade + soft.rgb * 0.06 + rim * edge * rim_amount;
	COLOR = vec4(col, max(soft.a, softer.a * 0.6) * opacity);
}
