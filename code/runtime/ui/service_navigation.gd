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
## Rendered above every caption. The hangar is the landing page that the other
## services sit inside, not one service among many, so it must not fall through
## to the trailing caption.
const LEADING_IDS: Array[String] = ["station"]
## Sidebar grouping by routine of use. Groups are captions only: no entry gains
## or loses eligibility, and every route keeps its own guard and docking rule.
## Entries missing from a group's list fall through to the trailing "其他" group,
## so adding a page to PAGES can never silently hide it.
const GROUPS: Array[Dictionary] = [
	{"title": "舰船", "ids": ["ships", "fitting", "drones"]},
	{"title": "物资", "ids": ["warehouse", "market", "industry"]},
	{"title": "任务", "ids": ["missions", "map"]},
	{"title": "势力", "ids": ["civilizations", "research"]},
	{"title": "系统", "ids": ["pause"]},
]
const OBSERVE_ICON: String = "res://assets/interface_v3/services/observe.svg"
## Marks the flight rail needs that are not workbench services. Reusing a service
## icon for them was one of the three collisions this revision fixes: 无人机 and
## 僚舰 both drew as 舰队与借船, and 雷达 drew as 科技与设施.
const EXTRA_ICONS: Dictionary = {
	"drones": "res://assets/interface_v3/services/drones.svg",
	"hire": "res://assets/interface_v3/services/hire.svg",
	"radar": "res://assets/interface_v3/services/radar.svg",
	"repair": "res://assets/interface_v3/services/repair.svg",
}
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
	if EXTRA_ICONS.has(id): return texture(str(EXTRA_ICONS[id]))
	return null

static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path] as Texture2D
