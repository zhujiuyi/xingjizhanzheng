class_name XJPresentationResources
extends RefCounted
## Presentation packs can advance without changing frozen world/asset identity.
const MANIFESTS: Array[String] = ["res://assets/interface_v2/manifest.json", "res://assets/hangar_v2/manifest.json", "res://assets/interface_v3/manifest.json", "res://assets/navigation_v3/manifest.json", "res://assets/ship_v3/manifest.json", "res://assets/station_v3/manifest.json", "res://data/local_navigation_v1_manifest.json", "res://data/warp_presentation_v3_manifest.json", "res://assets/business_v11/manifest.json", "res://assets/service_navigation_v3/manifest.json"]

static func validate() -> String:
	for manifest_path: String in MANIFESTS + ["res://assets/civilization_v1/manifest.json", "res://assets/fitting_v1/manifest.json", "res://assets/fleet_v1/manifest.json", "res://assets/materials_v1/manifest.json", "res://assets/effects_v1/manifest.json", "res://assets/ship_v4/manifest.json"]:
		if not FileAccess.file_exists(manifest_path): return "表现资源清单缺失：" + manifest_path
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not parsed is Dictionary or not parsed.get("resources") is Array or parsed.resources.is_empty():
			return "表现资源清单无效：" + manifest_path
		for entry: Variant in parsed.resources:
			if not entry is Dictionary: return "表现资源条目无效：" + manifest_path
			var path: String = str(entry.get("resource_path", entry.get("path", "")))
			if not path.begins_with("res://") or path.contains("..") or not FileAccess.file_exists(path):
				return "表现资源缺失：" + path
			if FileAccess.get_sha256(path) != str(entry.get("sha256", "")):
				return "表现资源摘要不匹配：" + path
			if path.get_extension() in ["png", "svg", "glb", "gdshader", "otf"] and not ResourceLoader.exists(path):
				return "表现资源导入缺失：" + path
	return ""
