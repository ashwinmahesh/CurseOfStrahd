class_name Graphics
extends RefCounted
## How much work the renderer does for the Modern finish (Improvement Ideas W2, W17): anti-aliasing on 3D edges, how
## sharp and soft the shadows are, and how many lamps may cast shadows at once, by a preset the player picks (Low,
## Medium or High; GameSettings "graphics"). The Classic finish keeps the renderer as it was when the owner froze it
## (2026-10-07), whatever the preset.
##
## Edges: MSAA smooths the edges of 3D shapes, and SMAA after it smooths the ink lines the screen pass draws round
## them (MSAA can't reach those: they're drawn per pixel after the scene). SMAA only blends along stair-stepped edges,
## so the character sprites, already smooth from their own shader, keep their detail; TAA would blur them.

const PRESETS: Array[String] = ["low", "medium", "high"]
const DEFAULT_PRESET := "high"

## Per preset:
## - msaa: samples on 3D edges; edge_aa: the screen-space pass over the finished picture (SMAA or the cheaper FXAA).
## - sun_map: the sun and moon's shadow map (pixels a side), shared by its splits; sun_splits: 2 or 4 bands from near
##   to far, each with its own share of the map, so shadows near the party are sharp.
## - lamp_atlas: the shadow atlas every other light draws into (pixels a side); lamp_shadows: how many lights
##   nearest the party cast shadows (Atmosphere picks them).
## - filter: soft shadow filtering for both (RenderingServer.ShadowQuality).
## - reflections: steps of the screen-space reflections on polished and wet surfaces (0 = none).
## - swaying: how many of the shadow-casting flames nearest the party sway as they flicker, stirring their shadows
##   (each redraws its shadow map every frame).
const SPECS := {
	"low": {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"sun_map": 2048, "sun_splits": 2, "lamp_atlas": 2048, "lamp_shadows": 2,
		"filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "reflections": 0, "swaying": 0},
	"medium": {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"sun_map": 4096, "sun_splits": 4, "lamp_atlas": 4096, "lamp_shadows": 6,
		"filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "reflections": 32, "swaying": 2},
	"high": {"msaa": Viewport.MSAA_4X, "edge_aa": Viewport.SCREEN_SPACE_AA_SMAA,
		"sun_map": 4096, "sun_splits": 4, "lamp_atlas": 8192, "lamp_shadows": 12,
		"filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "reflections": 56, "swaying": 4},
}
## The renderer as Classic was frozen with: no anti-aliasing, the sun's 4096 map in two splits, no lamp shadows,
## Godot's default soft filter. (project.godot holds High's settings for scenes that open without a place.)
const CLASSIC := {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
	"sun_map": 4096, "sun_splits": 2, "lamp_atlas": 4096, "lamp_shadows": 0,
	"filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "reflections": 0, "swaying": 0}


static func preset() -> String:
	var p := str(GameSettings.value("graphics", DEFAULT_PRESET))
	return p if p in PRESETS else DEFAULT_PRESET


## `save` false changes it for this run only (captures). Places built after a change use it; the viewport changes now.
static func set_preset(p: String, save: bool = true) -> void:
	if not p in PRESETS:
		return
	GameSettings.set_value("graphics", p, save)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		apply(tree.root)


## The settings in force: the preset's in the Modern finish, Classic's own otherwise.
static func spec() -> Dictionary:
	return SPECS[preset()] as Dictionary if Look.modern() else CLASSIC


## Sets the window's 3D rendering to the current preset (Atmosphere calls it as each place opens).
static func apply(vp: Viewport) -> void:
	var s := spec()
	vp.msaa_3d = s["msaa"] as Viewport.MSAA
	vp.screen_space_aa = s["edge_aa"] as Viewport.ScreenSpaceAA
	vp.positional_shadow_atlas_size = int(s["lamp_atlas"])
	vp.positional_shadow_atlas_16_bits = true
	RenderingServer.directional_shadow_atlas_set_size(int(s["sun_map"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(s["filter"] as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(s["filter"] as RenderingServer.ShadowQuality)


static func lamp_shadows() -> int:
	return int(spec()["lamp_shadows"])


static func sun_splits() -> int:
	return int(spec()["sun_splits"])


static func reflection_steps() -> int:
	return int(spec()["reflections"])


static func swaying_flames() -> int:
	return int(spec()["swaying"])
