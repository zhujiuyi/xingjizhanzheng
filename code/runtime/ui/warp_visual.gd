class_name XJWarpVisual
extends Control
## Original local-warp presentation; elapsed advances only with the host simulation.
var elapsed: float = 0.0
var phase: String = "idle"
var strength: float = 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func update_navigation(next_phase: String, delta: float, intensity: float, paused: bool) -> void:
	if next_phase != phase:
		elapsed = 0.0
		phase = next_phase
	strength = clampf(intensity, 0.0, 1.0)
	visible = phase in ["warmup", "travel"] and strength > 0.0
	if not paused: elapsed += delta
	if visible: queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var span: float = minf(size.x, size.y)
	var charging: bool = phase == "warmup"
	for index: int in range(40):
		var angle: float = float(index) * 2.399963
		var direction := Vector2(cos(angle), sin(angle))
		var progress: float = fposmod(elapsed * (0.12 if charging else 0.6) + float(index) * 0.137, 1.0)
		var radial: float = (0.18 + progress * 0.8) * span
		var length: float = span * (0.012 if charging else 0.07) * (0.6 + progress)
		var alpha: float = (0.1 if charging else 0.28) * sin(progress * PI) * strength
		draw_line(center + direction * radial, center + direction * (radial + length), Color(0.75, 0.83, 0.88, alpha), 1.0 if charging else 1.5, true)
