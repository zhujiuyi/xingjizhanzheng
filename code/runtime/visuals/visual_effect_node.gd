extends Node3D
## 仅视觉时钟，不产生业务事件或随机掉落；删除星区根节点会同时清除旧特效。
var duration_s: float = 0.0
var elapsed_s: float = 0.0
var shader_materials: Array[ShaderMaterial] = []
var follow_target: WeakRef
var follow_local_transform: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	# Effect poses already use the owner's interpolated render transform.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _process(delta: float) -> void:
	if follow_target != null:
		var target: Variant = follow_target.get_ref()
		if not is_instance_valid(target) or not target.is_inside_tree():
			queue_free()
			return
		global_transform = (target as Node3D).get_global_transform_interpolated() * follow_local_transform
	elapsed_s += delta
	for material: ShaderMaterial in shader_materials:
		material.set_shader_parameter("visual_time", elapsed_s)
		if duration_s > 0.0:
			material.set_shader_parameter("age", minf(elapsed_s / duration_s, 1.0))
	if duration_s > 0.0 and elapsed_s >= duration_s:
		queue_free()
