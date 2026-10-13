shader_type spatial;
// The outline round a 2D piece that a Search or a check just found, where it can be seen
// (found_outline_sprite.gdshaderinc).
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, blend_mix;

#include "res://shaders/world/found_outline_sprite.gdshaderinc"
