extends RefCounted
class_name SaveStore
## Versioned, checksummed Variant data. Objects are never deserialized.
## Write + verify a temporary file before replacement; retain last valid backup.

const MAX_BYTES := 8 * 1024 * 1024

static func write(path: String, state: Dictionary) -> Error:
	var directory := path.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(directory)
	if err != OK:
		return err
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := var_to_bytes({"format": 1, "state": state})
	file.store_buffer("SIMLIFE1".to_ascii_buffer())
	file.store_buffer(_digest(bytes))
	file.store_buffer(bytes)
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK:
		return err
	if read(path + ".tmp").is_empty():
		return ERR_FILE_CORRUPT
	if not read(path).is_empty():
		err = DirAccess.copy_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES or file.get_length() < 44:
		return {}
	if file.get_buffer(8).get_string_from_ascii() != "SIMLIFE1":
		return {}
	var digest := file.get_buffer(32)
	var bytes := file.get_buffer(file.get_length() - 40)
	file.close()
	if _digest(bytes) != digest:
		return {}
	var envelope = bytes_to_var(bytes)
	if not envelope is Dictionary or envelope.get("format") != 1 or not envelope.get("state") is Dictionary:
		return {}
	return envelope["state"]

static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	return hash_context.finish()
