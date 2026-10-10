class_name XJServiceNavigation
extends RefCounted
## Presentation registry shared by hangar, service sidebar, selector and headings.
## These captions and icons do not grant business permissions or store game data.
const PAGES: Array[Dictionary] = [
	{"id": "station", "label": "空间站", "icon": "res://assets/interface_v3/services/station.svg"},
	{"id": "ships", "label": "舰队与借船", "icon": "res://assets/interface_v3/services/ships.svg"},
	{"id": "warehouse", "label": "仓库与货舱", "icon": "res://assets/interface_v3/services/warehouse.svg"},
	{"id": "fitting", "label": "舰船配装", "icon": "res://assets/interface_v3/services/fitting.svg"},
	{"id": "market", "label": "站点市场", "icon": "res://assets/interface_v3/services/market.svg"},
	{"id": "industry", "label": "工业与回收", "icon": "res://assets/interface_v3/services/industry.svg"},
	{"id": "salvage", "label": "打捞鉴定", "icon": "res://assets/interface_v3/services/salvage.svg"},
	{"id": "missions", "label": "任务与合同", "icon": "res://assets/interface_v3/services/missions.svg"},
	{"id": "civilizations", "label": "文明与声望", "icon": "res://assets/interface_v3/services/civilizations.svg"},
	{"id": "research", "label": "科技与设施", "icon": "res://assets/interface_v3/services/research.svg"},
	{"id": "map", "label": "星域航路", "icon": "res://assets/interface_v3/services/map.svg"},
	{"id": "pause", "label": "暂停与存读档", "icon": "res://assets/interface_v3/services/pause.svg"},
]
const OBSERVE_ICON: String = "res://assets/interface_v3/services/observe.svg"
static var textures: Dictionary = {}

static func pages(docked: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in PAGES:
		# A docked hangar is a scene, not a service that can be opened in flight.
		# Other pages retain their existing docking explanations in XJUI.show_page.
		if str(record.id) == "station" and not docked: continue
		result.append(record)
	return result

static func label(id: String, fallback: String = "航行服务") -> String:
	for record: Dictionary in PAGES:
		if str(record.id) == id: return str(record.label)
	return fallback

static func icon(id: String) -> Texture2D:
	for record: Dictionary in PAGES:
		if str(record.id) == id: return texture(str(record.icon))
	return null

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path] as Texture2D
