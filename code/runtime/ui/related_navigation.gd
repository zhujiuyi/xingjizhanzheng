extends MenuButton
## Page navigation is separate from filters and never submits a business action.
const Interaction = preload("res://runtime/ui/ui_interaction.gd")
const UISkin = preload("res://runtime/ui_theme.gd")
var owner_ui: Node
var context: Dictionary
var destinations: Array[Dictionary] = []

func configure(ui: Node, entries: Array[Dictionary]) -> void:
	owner_ui = ui
	context = Interaction.context(ui)
	destinations = entries
	name = "RelatedNavigation"
	text = "相关功能"
	tooltip_text = "前往相关功能；返回时回到当前页面。"
	custom_minimum_size = Vector2(88, 32)
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_SHRINK_END
	UISkin.apply_button(self, "secondary", true)
	var popup: PopupMenu = get_popup()
	for index: int in range(entries.size()):
		popup.add_item(str(entries[index].title), index)
		popup.set_item_metadata(index, str(entries[index].id))
	popup.id_pressed.connect(_selected)
	popup.about_to_popup.connect(func():
		if not Interaction.current(owner_ui, context, self): popup.hide())

func _selected(index: int) -> void:
	if not Interaction.current(owner_ui, context, self) or index < 0 or index >= destinations.size(): return
	owner_ui.call("_open_related", str(destinations[index].id))
