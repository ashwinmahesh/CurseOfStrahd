class_name AtomicJson
extends RefCounted
## A verified sibling write, then an atomic rename. The live file is never truncated. A previous valid copy
## survives a corrupt file on the next launch; unfinished .tmp files are never treated as committed saves.


static func read(path: String) -> Dictionary:
	var data := read_one(path)
	return data if not data.is_empty() else read_one(path + ".bak")


static func read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var value: Variant = parser.data
	return value as Dictionary if value is Dictionary else {}


## Fault injection runs before each boundary; production callers omit it.
static func write(path: String, data: Dictionary, fault: Callable = Callable()) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var temp := path + ".tmp"
	if _fails(fault, "write"):
		return ERR_FILE_CANT_WRITE
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var encoded := JSON.stringify(data, "\t")
	file.store_string(encoded)
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK or _fails(fault, "verify") or FileAccess.get_file_as_string(temp) != encoded:
		return ERR_FILE_CANT_WRITE
	# Never replace the last good backup with a corrupt primary.
	if not read_one(path).is_empty():
		if _fails(fault, "backup"):
			return ERR_FILE_CANT_WRITE
		err = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if err != OK:
			return err
		err = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if err != OK:
			return err
	if _fails(fault, "commit"):
		return ERR_FILE_CANT_WRITE
	return DirAccess.rename_absolute(temp, path)


static func _fails(fault: Callable, step: String) -> bool:
	return fault.is_valid() and bool(fault.call(step))


## Copy older generations before publishing a new primary. Failure can duplicate a generation, but never
## removes the newest committed save. Paths are newest first. Call write(paths[0], ...) only after success.
static func rotate(paths: Array[String], fault: Callable = Callable()) -> Error:
	for index in range(paths.size() - 1, 0, -1):
		var data := read(paths[index - 1])
		if data.is_empty():
			continue
		var err := write(paths[index], data, fault)
		if err != OK:
			return err
	return OK
