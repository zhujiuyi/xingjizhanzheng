extends Node
## Renders the 舰载徽记 icon set at its real display sizes for human review.
## Read-only: rasterises SVG sources into one contact-sheet PNG.
## Legibility at 18 px cannot be judged from path coordinates, only from pixels.
##
## The sheet carries no baked text (Image has no text drawing and headless builds
## no render target), so the row order is printed and must match when reading it:
## each row is one icon, left three cells are the previous artwork, right three are
## the new artwork, both at DISPLAY_SIZES.

const OUT_ENV := "XJ_INSIGNIA_PREVIEW_PNG"
const OLD_ENV := "XJ_INSIGNIA_PREVIEW_OLD"
const SOURCE := "res://assets/interface_v3/services/%s.svg"
const ICONS: Array[String] = [
	"observe", "ships", "hire", "drones", "station", "warehouse",
	"fitting", "market", "industry", "missions", "civilizations",
	"research", "map", "radar", "pause",
]
const DISPLAY_SIZES: Array[int] = [18, 22, 26]
const PAD: int = 10
const CELL: int = 34
const ROW: int = 38
const BG := Color("101418")
const RULE := Color("39444d")

var old_directory: String = ""

func _ready() -> void:
	old_directory = OS.get_environment(OLD_ENV)
	var columns: int = DISPLAY_SIZES.size() * 2
	var width: int = PAD * 2 + CELL * columns + 1
	var height: int = PAD * 2 + ROW * ICONS.size()
	var sheet: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	for index: int in ICONS.size():
		var icon: String = ICONS[index]
		var y: int = PAD + index * ROW
		var column: int = 0
		for size: int in DISPLAY_SIZES:
			_blit(sheet, _rasterise(_old_source(icon), size), size, PAD + column * CELL, y)
			column += 1
		for size: int in DISPLAY_SIZES:
			_blit(sheet, _rasterise(_new_source(icon), size), size, PAD + column * CELL, y)
			column += 1
		_draw_rule(sheet, PAD, y + ROW - 4, width - PAD * 2, true)
		_draw_rule(sheet, PAD + 3 * CELL, y + 2, ROW - 8, false)

	var target: String = OS.get_environment(OUT_ENV)
	if target.is_empty():
		target = "user://insignia-icons.png"
	var error: Error = sheet.save_png(target)
	print("INSIGNIA_PREVIEW_PATH ", target)
	print("INSIGNIA_PREVIEW_SIZE ", width, "x", height)
	print("INSIGNIA_PREVIEW_COLUMNS 旧18 旧22 旧26 | 新18 新22 新26")
	for index: int in ICONS.size():
		print("INSIGNIA_PREVIEW_ROW %d %s" % [index, ICONS[index]])
	print("INSIGNIA_PREVIEW_SAVE ", error)
	get_tree().quit(0 if error == OK else 1)

func _old_source(icon: String) -> String:
	if old_directory.is_empty():
		return ""
	var path: String = old_directory.path_join(icon + ".svg")
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

func _new_source(icon: String) -> String:
	if not ResourceLoader.exists(SOURCE % icon):
		return ""
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path(SOURCE % icon))

func _rasterise(source: String, size: int) -> Image:
	if source.is_empty():
		return null
	var image: Image = Image.new()
	# Rasterise the vector at the exact display size instead of downsampling a
	# 24 px bitmap: this is the artwork as authored, not as filtered.
	if image.load_svg_from_string(source, float(size) / 24.0) != OK:
		return null
	return image

func _blit(sheet: Image, source: Image, size: int, x: int, y: int) -> void:
	if source == null:
		return
	var offset: Vector2i = Vector2i(x + (CELL - size) / 2, y + (ROW - 8 - size) / 2)
	sheet.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), offset)

func _draw_rule(sheet: Image, x: int, y: int, length: int, horizontal: bool) -> void:
	for step: int in length:
		var point: Vector2i = Vector2i(x + step, y) if horizontal else Vector2i(x, y + step)
		if point.x >= 0 and point.y >= 0 and point.x < sheet.get_width() and point.y < sheet.get_height():
			sheet.set_pixelv(point, RULE)
