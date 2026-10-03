extends SceneTree
## One-off native renderer. Captures real ship_v3 GLBs, never runtime thumbnails.
const Style=preload("res://runtime/surface_style.gd")
const SHIP_IDS:Array[String]=["battleship_bastion","cruiser_horizon","destroyer_raptor","frigate_kestrel","frigate_lantern","miner_anvil","shuttle_swift","support_weaver","transport_caravan"]
const OUTPUT:String="res://assets/business_v11/ships/"
var captures:int=0

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Ship thumbnails require the native renderer; headless cannot certify pixels.")
		quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size=Vector2i(512,512)
	var viewport:SubViewport=SubViewport.new()
	viewport.size=Vector2i(768,768)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview:TextureRect=TextureRect.new()
	preview.texture=viewport.get_texture()
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	var stage:Node3D=Node3D.new();viewport.add_child(stage)
	var env:Environment=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(.018,.035,.046,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.56,.64,.72)
	env.ambient_light_energy=.85
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var world:WorldEnvironment=WorldEnvironment.new();world.environment=env;stage.add_child(world)
	var camera:Camera3D=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=.05
	stage.add_child(camera);camera.make_current()
	for index:int in range(3):
		var light:DirectionalLight3D=DirectionalLight3D.new()
		light.light_energy=[2.8,1.1,.7][index]
		light.light_color=[Color(1.,.96,.87),Color(.64,.78,.92),Color(.82,.91,1.)][index]
		light.rotation_degrees=[Vector3(-45,-40,0),Vector3(20,140,0),Vector3(-10,85,0)][index]
		light.shadow_enabled=index==0
		stage.add_child(light)
	for id:String in SHIP_IDS:
		var source:String="res://assets/ship_v3/"+id+".glb"
		var resource:Resource=load(source)
		if not resource is PackedScene:
			push_error("Missing formal GLB for thumbnail: "+source);quit(1);return
		var model:Node3D=(resource as PackedScene).instantiate() as Node3D
		if model==null:
			push_error("Invalid formal GLB for thumbnail: "+source);quit(1);return
		stage.add_child(model);Style.apply_ship(model)
		var bounds:AABB=_bounds(model)
		var center:Vector3=bounds.get_center()
		var extent:float=maxf(bounds.size.length(),1.)
		camera.position=center+Vector3(.78,.53,-.92).normalized()*extent*3.
		camera.far=extent*8.;camera.look_at(center)
		var inverse:Transform3D=camera.global_transform.affine_inverse()
		var projected_min:Vector2=Vector2(INF,INF)
		var projected_max:Vector2=Vector2(-INF,-INF)
		for corner:int in range(8):
			var projected:Vector3=inverse*bounds.get_endpoint(corner)
			projected_min=projected_min.min(Vector2(projected.x,projected.y))
			projected_max=projected_max.max(Vector2(projected.x,projected.y))
		var span:Vector2=projected_max-projected_min
		camera.size=maxf(span.x,span.y)*1.16
		# Center the projected bounds, including asymmetric original hulls.
		var shift:Vector2=(projected_min+projected_max)*.5
		camera.global_position+=camera.global_basis.x*shift.x+camera.global_basis.y*shift.y
		for frame:int in range(16):await process_frame
		await RenderingServer.frame_post_draw
		var image:Image=viewport.get_texture().get_image()
		image.resize(256,256,Image.INTERPOLATE_LANCZOS)
		var visible:Rect2i=image.get_used_rect()
		if visible.size.x<24 or visible.size.y<24 or visible.position.x<3 or visible.position.y<3 or visible.end.x>253 or visible.end.y>253:
			push_error("Empty or clipped native ship portrait: "+id+" visible="+str(visible));quit(1);return
		var result:Error=image.save_png(ProjectSettings.globalize_path(OUTPUT+id+".png"))
		if result!=OK:
			push_error("Ship thumbnail PNG could not be saved: "+id);quit(1);return
		captures+=1
		print("BUSINESS_V11_SHIP_RENDER ",id," size=256x256 source=",source," visible=",visible," result=",result)
		model.queue_free();await process_frame
	print("BUSINESS_V11_RENDER_RESULT ",captures,"/",SHIP_IDS.size()," renderer=",RenderingServer.get_current_rendering_method())
	preview.queue_free();viewport.queue_free()
	await process_frame;await process_frame
	quit(0 if captures==SHIP_IDS.size() else 1)

func _bounds(model:Node3D)->AABB:
	var state:Dictionary={"bounds":AABB(),"has_bounds":false}
	_accumulate(model,state)
	return state.bounds as AABB

func _accumulate(node:Node3D,state:Dictionary)->void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh!=null:
		var box:AABB=node.global_transform*(node as MeshInstance3D).get_aabb()
		state.bounds=(state.bounds as AABB).merge(box) if bool(state.has_bounds) else box
		state.has_bounds=true
	for child:Node in node.get_children():
		if child is Node3D:_accumulate(child as Node3D,state)
