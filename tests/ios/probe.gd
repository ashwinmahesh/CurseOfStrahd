extends Control
var native: Object
var status: Label
var controls: Dictionary = {}
var frames := 0
var access_value := "before"
var save_name := "test-save-%d" % Time.get_unix_time_from_system()
func _ready() -> void:
    var marker := FileAccess.open("user://ready.txt", FileAccess.WRITE)
    marker.store_string(str(Engine.get_version_info()))
    marker.close()
    var background := ColorRect.new()
    background.color = Color(0.2, 0.1, 0.3)
    background.size = Vector2(844, 390)
    add_child(background)
    native = ClassDB.instantiate("StrahdIOS")
    var box := VBoxContainer.new()
    box.position = Vector2(50, 50)
    box.size = Vector2(700, 250)
    add_child(box)
    status = Label.new()
    status.text = "Native bridge ready" if native != null else "Native bridge MISSING"
    status.add_theme_font_size_override("font_size", 24)
    box.add_child(status)
    for label: String in ["Import JSON from Files", "Share test save", "Update search value"]:
        var button := Button.new()
        button.text = label
        button.custom_minimum_size = Vector2(600, 60)
        box.add_child(button)
        controls[label] = button
        button.pressed.connect(func() -> void:
            if label.begins_with("Import"):
                native.call("import_save", ProjectSettings.globalize_path("user://import.json"))
            elif label == "Update search value":
                access_value = "zzzz"
            else:
                var file := FileAccess.open("user://" + save_name + ".json", FileAccess.WRITE)
                file.store_string("{\"test\":true}")
                file.close()
                native.call("share_save", ProjectSettings.globalize_path("user://" + save_name + ".json")))
func _process(_delta: float) -> void:
    if native == null: return
    frames += 1
    if frames % 20 == 0:
        var items: Array = [{"id": "status", "label": str(status.get_meta("native_result", "Native bridge ready")), "role": "text", "frame": [0.05, 0.02, 0.8, 0.06]}, {"id": "save_filename", "label": save_name, "role": "text", "frame": [0.05, 0.08, 0.8, 0.06]}]
        for label: String in controls:
            var control := controls[label] as Button
            var rect := control.get_global_rect()
            var size_ := Vector2(get_window().size)
            rect = (control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * control.get_global_transform().affine_inverse()) * rect
            rect.position -= Vector2(get_window().position)
            items.append({"id": label, "label": label, "value": access_value if label == "Update search value" else "", "hint": "", "role": "button", "frame": [rect.position.x / size_.x, rect.position.y / size_.y, rect.size.x / size_.x, rect.size.y / size_.y]})
        native.call("set_accessibility", JSON.stringify({"revision": "1", "items": items}))
    var messages: Array = JSON.parse_string(native.call("take_events"))
    for message: Dictionary in messages:
        status.text = str(message)
        if str(message["kind"]).begins_with("file_"):
            status.set_meta("native_result", message["kind"])
            if message["kind"] == "file_imported" and JSON.parse_string(FileAccess.get_file_as_string("user://import.json")) != {"test": true}:
                status.set_meta("native_result", "content_mismatch")
        if message["kind"] == "access_activate":
            var id := str(message["value"]).trim_prefix("1:")
            if controls.has(id):
                (controls[id] as Button).pressed.emit()
        print("NATIVE_EVENT ", message)
