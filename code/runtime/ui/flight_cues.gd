extends PanelContainer
## A bounded persistent status strip; full details are available on hover.
const Navigation = preload("res://runtime/ui/service_navigation.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var list: VBoxContainer
var compact: bool = false

func _ready() -> void:
	name="FlightStatusCues"
	mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",UISkin.hud_panel(5))
	list=VBoxContainer.new(); list.add_theme_constant_override("separation",4); add_child(list)
	hide()

func refresh(game: RefCounted, small: bool, show_hud: bool) -> void:
	if list==null: return
	compact=small
	var cues: Array[Dictionary] = game.situational.cues() if game!=null else []
	visible=show_hud and not cues.is_empty()
	if not visible: return
	var all: PackedStringArray=[]
	for cue: Dictionary in cues: all.append(str(cue.title)+" · "+str(cue.detail))
	tooltip_text="\n".join(all)
	var count: int = mini(cues.size(),1 if compact else int(game.situational.balance.max_flight_cues))
	while list.get_child_count()>count:
		var child: Node=list.get_child(list.get_child_count()-1);list.remove_child(child);child.queue_free()
	while list.get_child_count()<count:
		var row: HBoxContainer=HBoxContainer.new();row.add_theme_constant_override("separation",6);list.add_child(row)
		var icon: TextureRect=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(18,18);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
		var label: Label=Label.new();label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.clip_text=true;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
		var badge: Label=Label.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(badge)
	for index: int in range(count):
		var cue: Dictionary=cues[index]
		var row: HBoxContainer=list.get_child(index)
		var icon: TextureRect=row.get_child(0);icon.texture=Navigation.icon(cue.icon_page)
		var label: Label=row.get_child(1);label.add_theme_font_size_override("font_size",10 if compact else 12)
		label.text=str(cue.title)+" · "+str(cue.detail)
		var badge: Label=row.get_child(2);badge.text="+%d" % (cues.size()-count) if index==count-1 and cues.size()>count else ""
		badge.add_theme_font_size_override("font_size",10 if compact else 12)
		label.add_theme_color_override("font_color",Color("ffbba2") if cue.severity=="danger" else UISkin.WARN if cue.severity=="warning" else UISkin.ICE)
