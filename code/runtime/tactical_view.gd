class_name XJTacticalView
extends Node3D
## Telegraphs read typed ability state. They never apply damage or healing.
var world: Node3D
var intensity: float = 1.0
var lines: Dictionary = {}
func setup(owner_world: Node3D) -> void: world = owner_world
func _process(_delta: float) -> void:
	if not is_instance_valid(world) or world.gameplay == null: return
	var g: RefCounted = world.gameplay
	var retained: Array[String] = []
	for row: RefCounted in world.state.rows("npc_tactic_state"):
		if row.phase not in ["charging","active"] or not world.npcs.has(row.npc_instance_id): continue
		retained.append(row.npc_instance_id)
		var body: Node3D = world.npcs[row.npc_instance_id]
		var spec: Dictionary = g.tactics.definition(row.npc_instance_id)
		var end: Vector3 = Vector3(row.aim_x,row.aim_y,row.aim_z)
		if spec.tactic_kind != "siege" and row.has_target_entity_id:
			if row.target_entity_id == world.state.ship().ship_instance_id: end = world.flight.position
			elif world.npcs.has(row.target_entity_id): end = world.npcs[row.target_entity_id].position
		var line: MeshInstance3D
		if not lines.has(row.npc_instance_id):
			line = MeshInstance3D.new(); line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.mesh = ImmediateMesh.new()
			var material: StandardMaterial3D = StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = {"support":Color(0.3,1.0,0.65,0.7),"interceptor":Color(1.0,0.8,0.25,0.7),"siege":Color(1.0,0.35,0.2,0.7),"carrier":Color(0.35,0.7,1.0,0.7)}[spec.tactic_kind]
			line.material_override = material; add_child(line); lines[row.npc_instance_id] = line
		else: line = lines[row.npc_instance_id]
		line.visible = intensity > 0.0
		(line.material_override as StandardMaterial3D).albedo_color.a = 0.7 * clampf(intensity,0.0,1.0)
		var mesh: ImmediateMesh = line.mesh as ImmediateMesh; mesh.clear_surfaces(); mesh.surface_begin(Mesh.PRIMITIVE_LINES); mesh.surface_add_vertex(body.position); mesh.surface_add_vertex(end); mesh.surface_end()
	for row: RefCounted in world.state.rows("remote_support_state"):
		if row.phase != "cycling" or not world.npcs.has(row.target_npc_id) or not is_instance_valid(world.flight): continue
		var id: String = "player_support:"+row.item_instance_id
		retained.append(id)
		_player_line(id,world.flight.position,world.npcs[row.target_npc_id].position,Color(0.3,0.75,1.0,0.6) if row.layer_id == "shield" else Color(0.3,1.0,0.65,0.6))
	for id: String in lines.keys():
		if not retained.has(id): lines[id].queue_free(); lines.erase(id)

func _player_line(id: String,source: Vector3,target: Vector3,color: Color) -> void:
	var line: MeshInstance3D
	if lines.has(id): line = lines[id]
	else:
		line = MeshInstance3D.new(); line.mesh = ImmediateMesh.new()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = material; add_child(line); lines[id] = line
	line.visible = intensity > 0.0
	color.a *= clampf(intensity,0.0,1.0)
	(line.material_override as StandardMaterial3D).albedo_color = color
	var mesh: ImmediateMesh = line.mesh as ImmediateMesh
	mesh.clear_surfaces(); mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(source); mesh.surface_add_vertex(target); mesh.surface_end()
