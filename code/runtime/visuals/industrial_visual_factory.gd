class_name XJIndustrialVisualFactory
extends RefCounted
## Independent ship presentation pack. Original wrapper bytes remain physics authority.
const Base=preload("res://runtime/visuals/visual_factory.gd")
const SHIPS=Base.SHIPS
const VISUAL_ROOT:String="res://assets/ship_v3/"

static func scene(ship_id:String)->CharacterBody3D:
	var path:String="res://assets/ships/"+ship_id+".tscn"
	if not ResourceLoader.exists(path):
		push_error("Missing immutable ship wrapper: "+ship_id)
		return null
	var resource:Resource=load(path)
	if not resource is PackedScene:
		push_error("Invalid immutable ship wrapper: "+ship_id)
		return null
	var instance:Node=(resource as PackedScene).instantiate()
	if not instance is CharacterBody3D:
		if instance!=null:instance.free()
		push_error("Invalid ship CharacterBody3D: "+ship_id)
		return null
	var wrapper:CharacterBody3D=instance as CharacterBody3D
	var visual:Node3D=wrapper.get_node_or_null("VisualRoot") as Node3D
	var previous:Node3D=wrapper.get_node_or_null("VisualRoot/Model") as Node3D
	if visual==null or previous==null:
		wrapper.free()
		push_error("Missing immutable ship visual hierarchy: "+ship_id)
		return null
	var model:Node3D=_model(ship_id)
	if model==null:
		wrapper.free()
		return null
	var original_transform:Transform3D=previous.transform
	visual.remove_child(previous);previous.free()
	model.name="Model";model.transform=original_transform;visual.add_child(model)
	wrapper.set_meta("visual_asset_version","ship-v3-industrial")
	return wrapper

static func ship(ship_id:String,color:Color=Color.TRANSPARENT)->Node3D:
	var model:Node3D=_model(ship_id)
	if model==null:return null
	model.name="Visual_"+ship_id;model.set_meta("ship_def_id",ship_id)
	if color.a>0:_tint(model,color)
	return model

static func enemy_scene(archetype:String="scout")->CharacterBody3D:
	var result:CharacterBody3D=scene(_enemy_id(archetype))
	if result!=null and not ("silent" in archetype or "relic" in archetype):_tint(result.get_node("VisualRoot") as Node3D,Color(.44,.12,.14))
	return result

static func enemy(template_id:String="scout")->Node3D:
	return ship(_enemy_id(template_id),Color.TRANSPARENT if "silent" in template_id or "relic" in template_id else Color(.44,.12,.14))

static func _enemy_id(archetype:String)->String:
	if "silent" in archetype or "relic" in archetype:return "enemy_silent"
	if archetype in SHIPS:return archetype
	if "raider" in archetype:return "destroyer_raptor"
	if "guardian" in archetype:return "cruiser_horizon"
	return "frigate_kestrel"

static func _model(ship_id:String)->Node3D:
	var path:String=VISUAL_ROOT+ship_id+".glb"
	if not ResourceLoader.exists(path):
		push_error("Missing industrial visual: "+ship_id)
		return null
	var resource:Resource=load(path)
	if not resource is PackedScene:
		push_error("Invalid industrial PackedScene: "+ship_id)
		return null
	var instance:Node=(resource as PackedScene).instantiate()
	if not instance is Node3D:
		if instance!=null:instance.free()
		push_error("Invalid industrial Node3D: "+ship_id)
		return null
	var model:Node3D=instance as Node3D
	model.set_meta("visual_asset_version","ship-v3-industrial")
	return model

static func _tint(node:Node3D,color:Color)->void:
	if node is MeshInstance3D:
		var mesh:MeshInstance3D=node as MeshInstance3D
		for index:int in range(mesh.mesh.get_surface_count()):
			var material:Material=mesh.get_active_material(index)
			if not material is StandardMaterial3D:continue
			var name:String=material.resource_name.to_lower()
			if not (name.ends_with("_paint") or name.ends_with("_hull")):continue
			var copy:StandardMaterial3D=material.duplicate() as StandardMaterial3D
			copy.albedo_color=copy.albedo_color.lerp(color,.30 if name.ends_with("_paint") else .10)
			mesh.set_surface_override_material(index,copy)
	for child:Node in node.get_children():
		if child is Node3D:_tint(child as Node3D,color)

static func sector(id:String)->Node3D:return Base.sector(id)
static func space_background(config:Dictionary)->Node3D:return Base.space_background(config)
static func sound(id:String)->AudioStream:return Base.sound(id)
static func static_body(kind:String,id:String,parameter:String="")->StaticBody3D:return Base.static_body(kind,id,parameter)
static func station()->Node3D:return Base.station()
static func gate()->Node3D:return Base.gate()
static func ore(kind:String="iron")->Node3D:return Base.ore(kind)
static func wreck()->Node3D:return Base.wreck()
static func geometry(ship_id:String)->Dictionary:return Base.geometry(ship_id)
static func configure(node:Node3D,profile:Dictionary)->void:Base.configure(node,profile)
