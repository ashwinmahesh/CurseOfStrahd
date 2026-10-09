class_name Icons
extends RefCounted
## Spell, item and ability icons: framed tiles in art/icons/<spells|items|features>/<key>.png (make icons, from
## art/icons.json; the silhouettes are game-icons.net, CC BY 3.0). A spell or item names its key with "icon" in its
## data, or is keyed by its own id. A magic item built on a mundane one ("+1 Longsword") takes its template's icon,
## else its base item's.
## The tiles carry their own colours, so they're drawn untinted (the theme tints plain button icons gilt).

const DIR := "res://art/icons/"

static var _cache: Dictionary = {}


static func spell(id: String) -> Texture2D:
	return _load("spells", spell_key(id))


static func item(id: String) -> Texture2D:
	return _load("items", item_key(id))


## An ability a hero switches on (Rage, Bladesong; art/icons.json "features"), or the plain rune tile for one without
## its own (EffectIcons).
static func feature(id: String) -> Texture2D:
	var tex := _load("features", id)
	return tex if tex != null else _load("features", "_any")


static func spell_key(id: String) -> String:
	return str(Compendium.shared().spell_data(id).get("icon", id))


static func item_key(id: String) -> String:
	var comp := Compendium.shared()
	var d := comp.item_data(id)
	if d.has("icon"):
		return str(d["icon"])
	var template := comp.item_data(str(d.get("template_id", "")))
	if template.has("icon"):
		return str(template["icon"])
	var base := str(d.get("base_item", ""))
	if base != "":
		return str(comp.item_data(base).get("icon", base))
	return id


## Common actions and class abilities with a tile of their own in art/icons.json "features", keyed by their hotbar id
## (Combat HUD plan, 2026-10-09: an icon on every slot).
const ACTION_ICONS: Array[String] = ["dash", "disengage", "dodge", "help", "hide", "search", "study", "ready", "grapple",
	"swap_weapons", "stabilize", "drop_prone", "stand", "influence", "utilize", "second_wind", "action_surge", "steady_aim",
	"turn_undead", "preserve_life", "escape"]
## Hotbar ids whose tile has another key.
const ACTION_ALIASES := {"shove_prone": "shove", "shove_push": "shove", "cunning_dash": "cunning", "cunning_disengage": "cunning",
	"cunning_hide": "cunning", "divine_spark_heal": "divine_spark", "divine_spark_harm": "divine_spark", "fly:up": "fly",
	"fly:down": "fly"}


## The icon for a hotbar entry (combat/action_catalog.gd): its spell, the weapon it attacks with, the item it uses, the
## tile of a common action or class ability (the plain rune for an ability without its own), or a container's (its
## name's tile, else its first choice's). null for a rule (a toggle shows its mode instead).
static func for_action(action: Dictionary) -> Texture2D:
	if action.has("policy") or bool(action.get("toggle", false)):
		return null
	# A magic item's power (a wand's Fireball): the item's own icon.
	if str(action.get("item_id", "")) != "":
		return item(str(action["item_id"]))
	var sid := str(action.get("spell_id", ""))
	if sid != "":
		return spell(sid)
	var id := str(action.get("id", ""))
	match id.get_slice(":", 0):
		"item":
			return item(id.get_slice(":", 1))
		"attack", "offhand":
			var option := id.substr(id.find(":") + 1)
			if option.begins_with("weapon:") or option.begins_with("thrown:"):
				return item(option.get_slice(":", 1).get_slice("@", 0))
		"healers_kit":
			return item("healers_kit")
		"haste", "jump":
			return spell(id.get_slice(":", 0))
		"escape_effect":
			return _load("features", "escape")
		"feat", "rider":
			var key := ActionCatalog.ability_key(action) if id.begins_with("feat:") else id.substr(6)
			return feature(ACTION_ALIASES.get(key, key) as String)
	if bool(action.get("group", false)):
		var own := _load("features", str(action["label"]).to_lower().replace(" ", "_"))
		if own != null:
			return own
		var items := action.get("items", []) as Array
		return for_action(items[0] as Dictionary) if not items.is_empty() else null
	if ACTION_ALIASES.has(id):
		return _load("features", str(ACTION_ALIASES[id]))
	if id in ACTION_ICONS:
		return _load("features", id)
	return null


## A square icon to start a list row with.
static func rect(tex: Texture2D, side: int = 32) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Puts `tex` on a button at `side` pixels, in its own colours (dimmed while the button is disabled).
static func on_button(b: Button, tex: Texture2D, side: int = 32) -> void:
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", side)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(0.55, 0.55, 0.55))


static func _load(kind: String, key: String) -> Texture2D:
	var path := DIR + "%s/%s.png" % [kind, key]
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[path] as Texture2D
