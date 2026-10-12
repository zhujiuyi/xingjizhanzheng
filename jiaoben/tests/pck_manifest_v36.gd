extends SceneTree
## Read every shipped virtual file using the actual EXE/PCK. No game world or
## user progress is opened. Used only to audit diagnostic-only repackaging.
var files: Dictionary={}

func _initialize() -> void:
	var output: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--xj-pck-manifest-out="):output=arg.trim_prefix("--xj-pck-manifest-out=").replace("\\","/")
	if not output.is_absolute_path() or not output.contains("/jiaoben/tmp/pck-v36/") or output.contains("..") or FileAccess.file_exists(output):quit(2);return
	if not walk("res://"):quit(2);return
	var stream: FileAccess=FileAccess.open(output,FileAccess.WRITE)
	if stream==null:quit(2);return
	stream.store_string(JSON.stringify({"exe":OS.get_executable_path(),"version":ProjectSettings.get_setting("application/config/version"),"files":files},"\t"));stream.close()
	print("PCK_MANIFEST_V36_RESULT PASS files=",files.size())
	quit(0)

func walk(path: String) -> bool:
	var directory: DirAccess=DirAccess.open(path)
	if directory==null:return false
	directory.include_hidden=true;directory.include_navigational=false
	for name: String in directory.get_files():
		var file: String=path.path_join(name)
		var digest: String=FileAccess.get_sha256(file)
		if digest.is_empty():return false
		files[file]=digest
	for name: String in directory.get_directories():
		if not walk(path.path_join(name)):return false
	return true
