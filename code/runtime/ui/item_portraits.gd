class_name XJItemPortraits
extends RefCounted
## Baked business thumbnails only. Game definitions and quotes stay in SQLite.
const ASSET_ROOT:String="res://assets/business_v11/"
const MANIFEST_PATH:String=ASSET_ROOT+"manifest.json"
static var _paths:Dictionary={}
static var _textures:Dictionary={}
static var _initialized:bool=false

static func asset_path(kind:String,id:String)->String:
	_initialize()
	var canonical:String=_canonical_kind(kind)
	var key:String=canonical+":"+id
	if _paths.has(key):return str(_paths[key])
	# The generic ship mark is explicitly unidentified; it is not a fake hull.
	var fallback:String=canonical if canonical in ["ship","item","research","facility","mission","blueprint"] else "item"
	return ASSET_ROOT+"generic/"+fallback+".svg"

static func texture(kind:String,id:String)->Texture2D:
	var path:String=asset_path(kind,id)
	if _textures.has(path):return _textures[path] as Texture2D
	var resource:Resource=load(path) if ResourceLoader.exists(path) else null
	var result:Texture2D=resource as Texture2D
	if result==null:
		result=load(ASSET_ROOT+"generic/item.svg") as Texture2D
	_textures[path]=result
	return result

static func _canonical_kind(kind:String)->String:
	match kind:
		"hull","ships":return "ship"
		"module","equipment","cargo","material","ore","ammo":return "item"
		"base_module","base":return "facility"
		"recipe","hull_recipe":return "blueprint"
	return kind

static func _initialize()->void:
	if _initialized:return
	_initialized=true
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:return
	var entries:Variant=(parsed as Dictionary).get("entries",[])
	if not entries is Array:return
	for entry:Variant in entries:
		if not entry is Dictionary:continue
		var value:Dictionary=entry as Dictionary
		var kind:String=str(value.get("kind",""))
		var id:String=str(value.get("id",""))
		var path:String=str(value.get("resource_path",""))
		if not kind.is_empty() and not id.is_empty() and path.begins_with(ASSET_ROOT):
			_paths[kind+":"+id]=path
