extends Node
## Compile every project script/scene with autoload globals available.

func _ready() -> void:
	var files: Array[String] = []
	_scan("res://scripts", files)
	_scan("res://tests", files)
	_scan("res://scenes", files)
	_scan("res://assets", files)
	var failures := 0
	for path in files:
		for dependency in ResourceLoader.get_dependencies(path):
			var parts := dependency.split("::")
			var resource_path := parts[parts.size() - 1]
			if resource_path.begins_with("res://") and not ResourceLoader.exists(resource_path):
				failures += 1
				push_error("AUDIT_DEPENDENCY_FAIL " + path + " -> " + resource_path)
		var resource := load(path)
		if resource == null or (resource is Script and not resource.can_instantiate()):
			failures += 1
			push_error("AUDIT_FAIL " + path)
	print("PROJECT_AUDIT: ", files.size(), " scripts/scenes/resources, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _scan(directory: String, files: Array[String]) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.get_extension() in ["gd", "tscn", "material", "gdshader", "tres"]:
			files.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		_scan(directory.path_join(child), files)
