@tool
extends EditorPlugin
## Formal editor integration: build/test drivers remain in jiaoben/export.
## Source hashes remain exact in PCK; default import/remap is not skipped.
var exporter: EditorExportPlugin

class RawAssetExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "XJRawAssetIntegrity"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		var count: int = 0
		var included: Dictionary = {}
		for manifest_path in ["res://assets/manifest.json", "res://assets/placeholders/manifest.json", "res://assets/interface_v2/manifest.json", "res://assets/hangar_v2/manifest.json", "res://assets/interface_v3/manifest.json", "res://assets/navigation_v3/manifest.json", "res://assets/ship_v3/manifest.json", "res://assets/station_v3/manifest.json", "res://data/local_navigation_v1_manifest.json", "res://data/warp_presentation_v3_manifest.json", "res://assets/business_v11/manifest.json", "res://assets/service_navigation_v3/manifest.json", "res://assets/civilization_v1/manifest.json"]:
			if not FileAccess.file_exists(manifest_path): continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if not parsed is Dictionary or not parsed.has("resources"):
				push_error("XJ export: invalid asset manifest " + manifest_path)
				continue
			add_file(manifest_path, FileAccess.get_file_as_bytes(manifest_path), false)
			for entry in parsed.resources:
				var source_path: String = entry.get("resource_path", entry.get("path", ""))
				if included.has(source_path): continue
				if not source_path.begins_with("res://") or source_path.contains("..") or not FileAccess.file_exists(source_path) or FileAccess.get_sha256(source_path) != entry.sha256:
					push_error("XJ export: missing/hash-mismatched original source " + source_path)
					continue
				# false keeps the raw entry at its exact source path. Imported
				# .godot resources and .remap records continue their default export.
				add_file(source_path, FileAccess.get_file_as_bytes(source_path), false)
				included[source_path] = true
				count += 1
		print("XJ_RAW_ASSET_EXPORT sources=", count)

func _enter_tree() -> void:
	exporter = RawAssetExport.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	if exporter != null:
		remove_export_plugin(exporter)
		exporter = null
