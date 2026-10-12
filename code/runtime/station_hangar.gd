class_name XJStationHangar
extends Node3D
## Isolated visual stage only: never consumes a WorldSnapshot, physics or save state.
const Factory=preload("res://runtime/visuals/industrial_visual_factory.gd")
const SurfaceStyle=preload("res://runtime/surface_style.gd")
const Space=preload("res://runtime/space_coordinates.gd")
const Navigation=preload("res://runtime/navigation_catalog.gd")
const StrategicWindow=preload("res://runtime/ui/window_space_strategic.gdshader")
const ROOT="res://assets/hangar_v2/"
const HANGAR_LAYER:int=1<<19
const SERVICE_TITLES={"operations":"站务 · 航路值班官","industry":"工业 · 舰务技师","research":"科研 · 遗构分析师","supplies":"补给 · 物资协调员"}
var ship_def_id:String="shuttle_swift"
var _catalog:RefCounted
var _layout:Dictionary={}
var _camera:Camera3D
var _showcase:Node3D
var _drone:Node3D
var _crew:Dictionary={}
var _time:float=0
var _built:bool=false
var _camera_destination:Vector3
var _camera_target:Vector3
var _view_target:Vector3
var _focused:String=""
var _window_mesh:MeshInstance3D
var _legacy_window_material:Material
var _space_window_material:ShaderMaterial
var _space_hash:String=""
var _space_station_id:String=""
var _space_context:Dictionary={}
var _station_yaw:float=0.0

func configure(definition_id:String,catalog:RefCounted)->void:
	_catalog=catalog
	ship_def_id=definition_id
	if _built:change_ship(definition_id)

func get_camera()->Camera3D:return _camera
func get_service_anchor(role:String)->Node3D:return _crew.get(role)

func set_space_context(catalog:XJCatalog,station_id:String)->bool:
	var hash_value:String=catalog.content_hash if catalog!=null else ""
	if hash_value==_space_hash and station_id==_space_station_id:
		_update_window_basis()
		return not _space_context.is_empty() or not Space.supported(catalog)
	_space_hash=hash_value;_space_station_id=station_id;_space_context={}
	if not Space.supported(catalog):
		_apply_space_window()
		return true
	var station:Dictionary=catalog.one("station_defs","station_id",station_id)
	var anchor:Dictionary=catalog.one("anchor_defs","anchor_id",str(station.get("station_anchor_id","")))
	if station.is_empty() or anchor.is_empty():_apply_space_window();return false
	var origin:Dictionary=Space.anchor_components(catalog,anchor)
	var star:Dictionary={}
	var planet:Dictionary={}
	for row:Dictionary in catalog.rows("celestial_defs"):
		if str(row.sector_id)!=str(station.sector_id):continue
		if row.celestial_kind=="star":star=row
		elif row.celestial_kind=="planet" and planet.is_empty():planet=row
	if origin.is_empty() or star.is_empty() or planet.is_empty():_apply_space_window();return false
	var star_point:Dictionary={"x":float(star.x_m),"y":float(star.y_m),"z":float(star.z_m)}
	var planet_point:Dictionary={"x":float(planet.x_m),"y":float(planet.y_m),"z":float(planet.z_m)}
	var star_distance:float=Space.scalar_distance(origin,star_point)
	var planet_distance:float=Space.scalar_distance(origin,planet_point)
	if not is_finite(star_distance) or not is_finite(planet_distance) or star_distance<=float(star.radius_m) or planet_distance<=float(planet.radius_m):_apply_space_window();return false
	_station_yaw=float(anchor.yaw_rad)
	var system:Dictionary=catalog.one("sector_defs","sector_id",str(station.sector_id))
	var light:Dictionary=catalog.one("system_lighting_defs","system_id",str(system.get("system_id","")))
	var palette:Dictionary={}
	for row:Dictionary in Navigation.rows("celestial_visual_defs"):
		if str(row.celestial_id)==str(planet.celestial_id):palette=row;break
	if light.is_empty() or palette.is_empty():_apply_space_window();return false
	_space_context={"content_hash":hash_value,"station_id":station_id,"sector_id":str(station.sector_id),"planet_id":str(planet.celestial_id),"star_id":str(star.celestial_id),
		"planet_direction":Space.scalar_direction(origin,planet_point),"planet_light_direction":Space.scalar_direction(planet_point,star_point),"star_direction":Space.scalar_direction(origin,star_point),
		"planet_sin_radius":float(planet.radius_m)/planet_distance,"star_sin_radius":float(star.radius_m)/star_distance,
		"planet_angle_rad":asin(float(planet.radius_m)/planet_distance),"star_angle_rad":asin(float(star.radius_m)/star_distance),
		"surface_color":Color(str(palette.surface_color)),"cloud_color":Color(str(palette.cloud_color)),"visual_seed":float(palette.visual_seed),
		"star_color":Color(float(light.light_r),float(light.light_g),float(light.light_b))}
	_apply_space_window()
	return true

func get_space_context()->Dictionary:
	return _space_context.duplicate(true)

func get_space_window_material()->ShaderMaterial:
	return _space_window_material if not _space_context.is_empty() else null

func _apply_space_window()->void:
	if not is_instance_valid(_window_mesh):return
	if _space_context.is_empty():_window_mesh.material_override=_legacy_window_material;return
	if _space_window_material==null:
		_space_window_material=ShaderMaterial.new();_space_window_material.shader=StrategicWindow
		_space_window_material.set_shader_parameter("space_panorama",preload("res://assets/navigation_v3/space_panorama.png"))
		_space_window_material.set_shader_parameter("surface_map",preload("res://assets/navigation_v3/planet_surface.png"))
	for key:String in ["planet_direction","planet_light_direction","star_direction","planet_sin_radius","star_sin_radius","surface_color","cloud_color","visual_seed","star_color"]:
		_space_window_material.set_shader_parameter(key,_space_context[key])
	_window_mesh.material_override=_space_window_material
	_update_window_basis()

func _update_window_basis()->void:
	if _space_window_material==null or _space_context.is_empty() or not is_inside_tree():return
	# The indoor stage uses exhibition coordinates. Only its ray orientation is
	# related to the station's actual yaw; its 15000m art offset is never a site.
	var stage_frame:Basis=Basis(Vector3.UP,_station_yaw)*global_basis.orthonormalized().inverse()
	_space_window_material.set_shader_parameter("stage_to_sector",stage_frame)

func _ready()->void:
	# The exhibition animates in render frames and remains active while menus
	# pause the world. Its camera must not inherit physics interpolation.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"layout.json"))
	if not parsed is Dictionary:push_error("Missing hangar exhibition layout");return
	_layout=parsed
	# Main can reposition/rotate this root. All framing uses to_global(local coordinates).
	position.y=float(_layout.world_offset_y)
	var environment_model:Node3D=_model("hangar_environment")
	add_child(environment_model)
	_apply_environment_metal(environment_model)
	_apply_terminals(environment_model)
	_build_window()
	_build_lighting()
	_build_crew()
	_drone=_model("service_drone");add_child(_drone)
	_showcase=Node3D.new();_showcase.name="ShipExhibition";add_child(_showcase)
	_showcase.position=_vector(_layout.showcase_position)
	_showcase.rotation.y=deg_to_rad(float(_layout.showcase_yaw_deg))
	_camera=Camera3D.new();_camera.name="HangarCamera";_camera.near=.1;_camera.far=180;_camera.fov=float(_layout.camera_fov_deg);_camera.cull_mask=HANGAR_LAYER
	_camera.environment=_camera_environment();add_child(_camera)
	_camera_destination=_vector(_layout.camera_position);_camera.position=_camera_destination
	_camera_target=_vector(_layout.camera_target);_view_target=_camera_target
	_camera.look_at(to_global(_view_target))
	_built=true
	change_ship(ship_def_id)
	_layer_subtree(self)

func change_ship(definition_id:String)->void:
	ship_def_id=definition_id
	if not _built:return
	for child in _showcase.get_children():_showcase.remove_child(child);child.queue_free()
	var wrapper:CharacterBody3D=Factory.scene(definition_id)
	if wrapper==null:push_error("Missing exhibition ship: "+definition_id);return
	# Retain the formal wrapper's visual transform; no collision body enters the hangar.
	var visual:Node3D=wrapper.get_node("VisualRoot") as Node3D
	wrapper.remove_child(visual);wrapper.free()
	_showcase.add_child(visual)
	SurfaceStyle.apply_ship(visual)
	var geometry:Dictionary=Factory.geometry(definition_id)
	var length_m:float=float(geometry.get("length_m",1.0))
	visual.scale*=float(_layout.showcase_length_m)/maxf(length_m,1.0)
	_layer_subtree(visual)
	focus_service("")

func focus_service(role:String)->void:
	if not _built:return
	_focused=role if _crew.has(role) else ""
	if _focused.is_empty():
		_camera_destination=_vector(_layout.camera_position);_camera_target=_vector(_layout.camera_target);_camera.fov=float(_layout.camera_fov_deg)
	else:
		var crew:Node3D=_crew[_focused]
		_camera_target=crew.position+Vector3(0,1.25,0)
		_camera_destination=crew.position+Vector3(2.9,2.25,4.5)
		_camera.fov=43

func _process(delta:float)->void:
	if not _built or not is_visible_in_tree():return
	_update_window_basis()
	_time+=delta
	_camera.position=_camera.position.lerp(_camera_destination,1.0-exp(-delta*3.4))
	_view_target=_view_target.lerp(_camera_target,1.0-exp(-delta*3.4))
	_camera.look_at(to_global(_view_target))
	_showcase.position.y=float(_layout.showcase_position[1])+sin(_time*.45)*.12
	var index:int=0
	for role in _crew:
		var crew:Node3D=_crew[role]
		var head:Node3D=crew.find_child("HeadPivot",true,false) as Node3D
		var hand:Node3D=crew.find_child("RightArmPivot",true,false) as Node3D
		if head:head.rotation.y=sin(_time*.36+index*1.4)*.06
		if hand:hand.rotation.z=sin(_time*.65+index)*.035
		index+=1
	_drone.position=Vector3(sin(_time*.17)*12,11+sin(_time*.8)*.25,-8+cos(_time*.17)*4)
	_drone.rotation.y=-_time*.17

func _model(id:String)->Node3D:
	var scene:PackedScene=load(ROOT+id+".glb") as PackedScene
	if scene==null:push_error("Missing hangar model "+id);return Node3D.new()
	return scene.instantiate() as Node3D

func _build_crew()->void:
	for role:String in SERVICE_TITLES:
		var crew:Node3D=_model("crew_"+role);crew.name="Crew_"+role
		crew.position=_vector(_layout.crew_positions[role]);crew.rotation.y=.20
		add_child(crew);_crew[role]=crew
		_apply_terminals(crew)
		var title:Label3D=Label3D.new();title.name="ProfessionLabel";title.text=SERVICE_TITLES[role];title.position=Vector3(0,2.4,0)
		var font:FontFile=XJUITheme.font()
		title.font=font;title.font_size=30;title.pixel_size=.006;title.outline_size=5;title.modulate=Color(.56,.8,.86);title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		crew.add_child(title)

func _build_window()->void:
	var mesh:MeshInstance3D=MeshInstance3D.new();mesh.name="StarViewport"
	var quad:QuadMesh=QuadMesh.new();quad.size=Vector2(40,17.4);mesh.mesh=quad;mesh.position=Vector3(0,16,-33.5)
	var material:ShaderMaterial=ShaderMaterial.new();material.shader=load(ROOT+"window_space.gdshader");mesh.material_override=material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
	_window_mesh=mesh;_legacy_window_material=material
	_apply_space_window()

func _build_lighting()->void:
	var key:DirectionalLight3D=DirectionalLight3D.new();key.name="ExhibitionKey";key.rotation_degrees=Vector3(-48,-26,0);key.light_color=Color(.73,.84,.92);key.light_energy=2.0;key.shadow_enabled=true;key.directional_shadow_max_distance=100;key.light_cull_mask=HANGAR_LAYER;add_child(key)
	var fill:DirectionalLight3D=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,135,0);fill.light_color=Color(.65,.42,.23);fill.light_energy=.5;fill.light_cull_mask=HANGAR_LAYER;add_child(fill)
	for point in [Vector3(-15,13,6),Vector3(8,16,-19),Vector3(4,5,22)]:
		var light:OmniLight3D=OmniLight3D.new();light.position=point;light.omni_range=29;light.light_color=Color(.26,.65,.85) if point.z<0 else Color(.8,.71,.58);light.light_energy=2.5;light.light_cull_mask=HANGAR_LAYER;add_child(light)

func _camera_environment()->Environment:
	var env:Environment=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.004,.009,.014)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.30,.43,.52);env.ambient_light_energy=.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=true;env.glow_intensity=.35;env.ssao_enabled=true;env.ssao_radius=1.2;env.ssao_intensity=1.1
	return env

func _apply_environment_metal(node:Node3D)->void:
	if node is MeshInstance3D:
		var mesh:MeshInstance3D=node
		for index in range(mesh.mesh.get_surface_count()):
			var original:Material=mesh.get_active_material(index)
			if original is StandardMaterial3D and "Metal" in original.resource_name:
				var mat:ShaderMaterial=ShaderMaterial.new();mat.shader=load(ROOT+"metal.gdshader");mat.set_shader_parameter("metal_tint",original.albedo_color)
				var texture_path:String="res://assets/interface_v2/metal_albedo.png"
				if ResourceLoader.exists(texture_path):mat.set_shader_parameter("metal_albedo",load(texture_path));mat.set_shader_parameter("has_albedo",true)
				mesh.set_surface_override_material(index,mat)
	for child in node.get_children():
		if child is Node3D:_apply_environment_metal(child)

func _layer_subtree(node:Node)->void:
	if node is VisualInstance3D:node.layers=HANGAR_LAYER
	for child in node.get_children():_layer_subtree(child)

func _apply_terminals(node:Node3D)->void:
	if node is MeshInstance3D:
		var mesh:MeshInstance3D=node
		for surface:int in range(mesh.mesh.get_surface_count()):
			var material:Material=mesh.get_active_material(surface)
			if material is StandardMaterial3D and material.resource_name=="Crew_Screen_Blue" and not "HeadPivot" in str(mesh.name):
				var copy:ShaderMaterial=ShaderMaterial.new();copy.shader=load(ROOT+"terminal.gdshader");mesh.set_surface_override_material(surface,copy)
	for child:Node in node.get_children():
		if child is Node3D:_apply_terminals(child as Node3D)

func _vector(value:Array)->Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
