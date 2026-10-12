extends Node
## Read every shipped virtual file using the actual EXE/PCK. No game world or
## user progress is opened. Used only to audit diagnostic-only repackaging.
var files: Dictionary={}
var visited: Dictionary={}

func _ready() -> void:
	collect.call_deferred()

func collect() -> void:
	print("PCK_MANIFEST_V36_BEGIN")
	var output: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--xj-pck-manifest-out="):output=arg.trim_prefix("--xj-pck-manifest-out=").replace("\\","/")
	if not output.is_absolute_path() or not output.contains("/jiaoben/tmp/pck-v36/") or output.contains("..") or FileAccess.file_exists(output):get_tree().quit(2);return
	if not walk("res://"):get_tree().quit(2);return
	var stream: FileAccess=FileAccess.open(output,FileAccess.WRITE)
	if stream==null:get_tree().quit(2);return
	stream.store_string(JSON.stringify({"exe":OS.get_executable_path(),"version":ProjectSettings.get_setting("application/config/version"),"files":files},"\t"));stream.close()
	print("PCK_MANIFEST_V36_RESULT PASS files=",files.size())
	get_tree().quit(0)

func walk(path: String, depth: int=0) -> bool:
	path=path.simplify_path()
	if depth>24:push_error("Unexpected packed directory depth: "+path);return false
	if visited.has(path):return true
	visited[path]=true
	var directory: DirAccess=DirAccess.open(path)
	if directory==null:return false
	directory.include_hidden=true;directory.include_navigational=false
	for name: String in directory.get_files():
		if name in [".",".."]:continue
		var file: String=path.path_join(name)
		var digest: String=FileAccess.get_sha256(file)
		if digest.is_empty():return false
		files[file]=digest
	for name: String in directory.get_directories():
		if name in [".",".."]:continue
		if not walk(path.path_join(name),depth+1):return false
	return true
