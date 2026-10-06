extends Node3D
## 仅视觉时钟，不产生业务事件或随机掉落；删除星区根节点会同时清除旧特效。
var duration_s: float = 0.0
var elapsed_s: float = 0.0
var shader_materials: Array[ShaderMaterial] = []

func _process(delta: float) -> void:
	elapsed_s += delta
	for material: ShaderMaterial in shader_materials:
		material.set_shader_parameter("visual_time", elapsed_s)
		if duration_s > 0.0:
			material.set_shader_parameter("age", minf(elapsed_s / duration_s, 1.0))
	if duration_s > 0.0 and elapsed_s >= duration_s:
		queue_free()
