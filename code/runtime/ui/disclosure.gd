extends RefCounted
## Presentation only: the owning panel retains its callback and visibility guard.
const UISkin = preload("res://runtime/ui_theme.gd")

static func apply(button: Button, title: String, expanded: bool, count: int = -1) -> void:
	button.toggle_mode = true
	button.set_pressed_no_signal(expanded)
	button.set_meta("ui_disclosure", true)
	button.set_meta("disclosure_title", title)
	button.set_meta("expanded", expanded)
	button.set_meta("count", count)
	button.text = ("v " if expanded else "> ") + title + (" · %d" % count if count >= 0 else "")
	button.tooltip_text = ("收起" if expanded else "展开") + title + ("（%d 项）" % count if count >= 0 else "")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", UISkin.SIZE_BODY)
	UISkin.apply_toolbar_button(button)
	# A checked disclosure is still a text row, with a visible hover/focus cue.
	for state: String in ["normal", "pressed"]:
		var surface: StyleBoxFlat = button.get_theme_stylebox(state)
		surface.bg_color = Color.TRANSPARENT
		surface.border_color = Color.TRANSPARENT
