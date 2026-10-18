class_name MobileNative
extends Node
## iOS-only services are instantiated dynamically, so desktop imports and play do not load native code.

signal file_result(kind: String, value: String)
static var current: MobileNative
var bridge: Object
var pending := false
var system_reduced_motion := false
var accessibility := MobileAccessibility.new()
var access_time := 0.0
const IMPORT := "user://transfers/incoming.json"
const SHARE := "user://transfers/CurseOfStrahd-save.json"


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("ios") and ClassDB.class_exists(&"StrahdIOS"):
		bridge = ClassDB.instantiate(&"StrahdIOS")
		bridge.call("observe_motion")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and available():
		# Godot 4.7.2 starts its audio unit immediately after this notification returns.
		# Reactivate synchronously; a deferred/main-queue task would race that restart.
		# This only prepares audio. MobileLifecycle still owns the player's Continue pause.
		var error := str(bridge.call("activate_audio_session"))
		if error != "":
			push_error("iOS audio session could not resume: " + error)


func _exit_tree() -> void:
	if current == self:
		current = null


func available() -> bool:
	return bridge != null


func import_save() -> void:
	if not available() or pending:
		return
	DirAccess.make_dir_recursive_absolute("user://transfers")
	pending = true
	UiFeel.touch.cancel()
	bridge.call("import_save", ProjectSettings.globalize_path(IMPORT))


func share_save(path: String) -> Error:
	return _share_json(path, SHARE)


func share_report(path: String) -> Error:
	return _share_json(path, "user://transfers/CurseOfStrahd-diagnostics.json")


func _share_json(path: String, destination: String) -> Error:
	if not available() or pending:
		return ERR_BUSY
	var err := SaveTransfer.share_copy(path, destination)
	if err != OK:
		return err
	pending = true
	UiFeel.touch.cancel()
	bridge.call("share_save", ProjectSettings.globalize_path(destination))
	return OK


func _process(delta: float) -> void:
	if bridge == null:
		return
	access_time -= delta
	if access_time <= 0 and not pending:
		access_time = 0.25
		_sync_accessibility()
	var messages: Variant = JSON.parse_string(str(bridge.call("take_events")))
	if not messages is Array:
		return
	for message: Dictionary in messages:
		var kind := str(message.get("kind", ""))
		if kind == "reduce_motion":
			system_reduced_motion = str(message.get("value", "")) == "1"
		if kind.begins_with("access_") and not pending:
			# Revalidate queued actions and publish any changed state to UIKit. A snapshot
			# advances the cached revision, so discarding it would strand native clients.
			_sync_accessibility()
			accessibility.activate(kind, str(message.get("value", "")))
		if kind.begins_with("file_"):
			pending = false
			accessibility.snapshot_key = 0
			file_result.emit(kind, str(message.get("value", "")))


func _sync_accessibility() -> void:
	var snapshot := accessibility.snapshot(get_tree().root)
	if not snapshot.is_empty():
		bridge.call("set_accessibility", JSON.stringify(snapshot))


static func feedback() -> void:
	if current != null and current.available() and not current.pending and bool(GameSettings.value("ios_haptics", true)):
		current.bridge.call("haptic")


## Mobile preference only; desktop keeps its existing animation and camera behavior.
static func reduced_motion() -> bool:
	return MobileDevice.enabled() and (bool(GameSettings.value("ios_reduce_motion", false))
		or current != null and current.system_reduced_motion)
