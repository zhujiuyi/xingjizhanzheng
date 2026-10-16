extends RefCounted
const T=preload("res://contracts/contract_types.gd")
const UISkin=preload("res://runtime/ui_theme.gd")
const Interaction=preload("res://runtime/ui/ui_interaction.gd")
const Disclosure=preload("res://runtime/ui/disclosure.gd")
var u: Node
var faction: String=""
var selected_stage: Dictionary={}
var values: Label
var note: Label
var outcome: Label
var choices: OptionButton
var paths: Array[Dictionary]=[]
var box: VBoxContainer
var context: Dictionary={}
var goals: Array[Dictionary]=[]
var preview: VBoxContainer
var preview_stage_id: String=""
var preview_fields: Dictionary={}
var routes_open: bool=false
var history_open: bool=false
var revision: int=0
var signature: String=""
var last_poll_ms: int=0
var activity_key: String=""

func build(ui: Node,selected_faction: String) -> void:
	u=ui;faction=selected_faction
	var growth: RefCounted=u.gameplay.growth
	if not growth.supported():return
	goals=growth.stages(faction)
	if goals.is_empty():return
	box=VBoxContainer.new();box.name="GrowthPanel";box.add_theme_constant_override("separation",UISkin.GAP);u.body.add_child(box)
	context=Interaction.context(u)
	_rebuild()

func _current() -> bool:
	return is_instance_valid(u) and is_instance_valid(box) and not box.is_queued_for_deletion() and not u.loading_suspended and Interaction.current(u,context,box) and u.page=="civilizations" and u.civilization_selected_faction==faction

func _recommended() -> Dictionary:
	# sort_order is guidance, never a new permission chain. A stored manual
	# future/completed choice must not mask the current recommended objective.
	for stage: Dictionary in goals:
		if not bool(u.gameplay.growth.progress(stage).complete):return stage
	return {}

func _mission_visible(path: Dictionary) -> bool:
	var missions: RefCounted=u.gameplay.missions
	var active: RefCounted=missions.active()
	if active!=null:return active.mission_def_id==path.reference_id
	var definition: Dictionary=u.gameplay.definition("mission_defs","mission_id",path.reference_id)
	if definition.is_empty() or (not bool(definition.repeatable) and missions.completed(path.reference_id)):return false
	if not u.gameplay.unlocked(definition.required_unlock_id) or not missions.missing_prerequisite(path.reference_id).is_empty():return false
	for row: RefCounted in u.state.rows("mission_state"):
		if row.mission_def_id==path.reference_id and row.cooldown_remaining_s>0.0:return false
	# eligible()/window() refresh persisted mission windows. This UI only reads
	# the availability already maintained by the actual mission service.
	var availability: RefCounted=u.state.find("mission_availability_state","mission_def_id",path.reference_id)
	return availability!=null and availability.status=="available"

func _current_paths(stage: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if stage.is_empty():return result
	for path: Dictionary in u.gameplay.growth.activities(stage.stage_id):
		if path.activity_kind=="mission" and not _mission_visible(path):continue
		if path.activity_kind=="honor":
			var task: Dictionary=u.gameplay.definition("civilization_honor_task_defs","task_id",path.reference_id)
			if not task.is_empty() and u.gameplay.honors.progress(path.reference_id)>=int(task.required_units):continue
		# The four commander proofs and donation alternatives are parallel.
		# Their availability stays with existing business services.
		result.append(path)
	return result

func _view_signature(stage: Dictionary,available: Array[Dictionary]) -> String:
	var result: String=str(stage.get("stage_id",""))+":"+str(u.state.ship().status)
	for path: Dictionary in available:result+="|"+str(path.stage_id)+":"+str(path.activity_index)
	for goal: Dictionary in goals:result+="|"+str(goal.stage_id)+":"+str(u.gameplay.growth.progress(goal).complete)
	return result

func _rebuild() -> void:
	if not _current():return
	var view: Dictionary=u.capture_local_view(box)
	if is_instance_valid(choices) and choices.selected>=0 and choices.selected<paths.size():activity_key=_path_key(paths[choices.selected])
	revision+=1
	for child: Node in box.get_children():box.remove_child(child);child.queue_free()
	selected_stage=_recommended();paths=_current_paths(selected_stage);choices=null;preview_fields={}
	u._text_to(box,"当前推荐目标",UISkin.SIZE_SECTION)
	if selected_stage.is_empty():
		u._text_to(box,"此文明成长目标均已达成。仍可按各系统资格继续选择活动。",UISkin.SIZE_BODY)
		values=null;note=null
	else:
		u._text_to(box,str(selected_stage.display_name),16).name="GrowthCurrentStage"
		values=u._text_to(box,"",14);values.name="GrowthValues";values.add_theme_color_override("font_color",UISkin.ICE)
		note=u._text_to(box,"",13);note.name="GrowthGap";note.add_theme_color_override("font_color",UISkin.MUTED)
		outcome=u._text_to(box,"收益 · "+str(selected_stage.outcome_label),13);outcome.add_theme_color_override("font_color",UISkin.MUTED)
		choices=_activities(box,paths,"Growth",false)
		if paths.is_empty():
			u._text_to(box,"当前没有可开始的任务。请在任务与合同查看前置、冷却或当前任务；其他途径可在下方规划。",13).add_theme_color_override("font_color",UISkin.MUTED)
			var planning: Array[Dictionary]=u.gameplay.growth.activities(selected_stage.stage_id)
			if not planning.is_empty():_actions(box,planning,null,"Growth",true)
	_build_routes()
	_build_history()
	signature=_view_signature(selected_stage,paths)
	_update_values()
	u._link_page_focus.call_deferred()
	u.finish_local_rebuild(box,view)

func _path_key(path: Dictionary) -> String:return str(path.stage_id)+":"+str(path.activity_index)

func _activities(parent: Node,available: Array[Dictionary],prefix: String,planning: bool) -> OptionButton:
	if available.is_empty():return null
	var picker: OptionButton=null
	if available.size()>1:
		picker=OptionButton.new();picker.name=prefix+"Activity";picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;picker.clip_text=true
		for path: Dictionary in available:
			picker.add_item(u.gameplay.growth.activity_label(path))
			if prefix=="Growth" and _path_key(path)==activity_key:picker.select(picker.item_count-1)
		parent.add_child(picker)
	else:u._text_to(parent,u.gameplay.growth.activity_label(available[0]),UISkin.SIZE_BODY)
	_actions(parent,available,picker,prefix,planning)
	return picker

func _actions(parent: Node,available: Array[Dictionary],picker: OptionButton,prefix: String,planning: bool) -> void:
	var controls:=HFlowContainer.new();controls.add_theme_constant_override("h_separation",UISkin.GAP);parent.add_child(controls)
	var witness: WeakRef=weakref(picker) if picker!=null else null
	var controls_ref: WeakRef=weakref(controls)
	var built: int=revision
	for action: String in ["growth_map","growth_navigate","growth_open"]:
		var callback: Callable=func():
			if not _current() or built!=revision:return
			var live_controls: Node=controls_ref.get_ref() as Node
			if not is_instance_valid(live_controls) or not live_controls.is_inside_tree() or live_controls.is_queued_for_deletion() or not box.is_ancestor_of(live_controls):return
			var index: int=0
			if witness!=null:
				var live: OptionButton=witness.get_ref() as OptionButton
				if not is_instance_valid(live) or not live.is_inside_tree() or live.is_queued_for_deletion():return
				index=live.selected
			if index<0 or index>=available.size():return
			var path: Dictionary=available[index]
			u.requested.emit(action,str(path.stage_id),1,str(path.activity_index))
		var caption: String={"growth_map":"定位途径","growth_navigate":"前往","growth_open":"查看前置" if planning and prefix=="Growth" else "打开服务"}[action]
		if action=="growth_open" and planning and prefix=="Growth" and selected_stage.criterion_kind=="honors":caption="办理认证"
		var button: Button=u._button(controls,caption,callback);button.name=prefix+"_"+action
		var reason: String=""
		if planning and prefix=="Growth" and action!="growth_open":reason="当前没有可开始的任务；可查看前置与资格。"
		elif action=="growth_navigate" and u.state.ship().status!=T.ShipStatus.FLYING:reason="请先出港；可用定位途径查看目标。"
		Interaction.action_state(button,reason)

func _build_routes() -> void:
	var later: Array[Dictionary]=[]
	for goal: Dictionary in goals:
		if str(goal.stage_id)!=str(selected_stage.get("stage_id","")) and not bool(u.gameplay.growth.progress(goal).complete):later.append(goal)
	if later.is_empty():return
	var fold: Button=u._button(box,"",_toggle_group.bind("routes"))
	fold.name="GrowthRoutesToggle"
	Disclosure.apply(fold,"其他路线 / 后续规划",routes_open,later.size())
	var content:=VBoxContainer.new();content.name="GrowthRoutes";content.visible=routes_open;box.add_child(content)
	u._text_to(content,"这是规划顺序；科技、考核、远征和工程仍按各自资格开放，可并行选择。",13).add_theme_color_override("font_color",UISkin.MUTED)
	var chosen: int=0
	for index: int in range(later.size()):
		if str(later[index].stage_id)==preview_stage_id:chosen=index
	var route_row:=HFlowContainer.new();route_row.add_theme_constant_override("h_separation",UISkin.GAP);content.add_child(route_row)
	var previous: Button=u._button(route_row,"上一目标",func():
		if _current() and chosen>0:preview_stage_id=str(later[chosen-1].stage_id);_rebuild())
	previous.name="GrowthPreviewPrevious";previous.disabled=chosen==0
	var current: Label=u._text_to(route_row,"%d / %d · %s" % [chosen+1,later.size(),later[chosen].display_name],UISkin.SIZE_BODY)
	current.name="GrowthStage";current.set_meta("stage_id",str(later[chosen].stage_id));current.set_meta("route_count",later.size())
	var next: Button=u._button(route_row,"下一目标",func():
		if _current() and chosen+1<later.size():preview_stage_id=str(later[chosen+1].stage_id);_rebuild())
	next.name="GrowthPreviewNext";next.disabled=chosen+1==later.size()
	preview=VBoxContainer.new();content.add_child(preview)
	_render_preview(later[chosen])

func _render_preview(stage: Dictionary) -> void:
	for child: Node in preview.get_children():preview.remove_child(child);child.queue_free()
	var progress: Label=u._text_to(preview,"",UISkin.SIZE_BODY)
	u._text_to(preview,"收益 · "+str(stage.outcome_label),13).add_theme_color_override("font_color",UISkin.MUTED)
	_activities(preview,u.gameplay.growth.activities(stage.stage_id),"GrowthPreview",true)
	preview_fields={"stage":stage,"label":progress}
	_update_values()
	u._link_page_focus.call_deferred()

func _build_history() -> void:
	var completed: Array[Dictionary]=[]
	for goal: Dictionary in goals:
		if bool(u.gameplay.growth.progress(goal).complete):completed.append(goal)
	if completed.is_empty():return
	var fold: Button=u._button(box,"",_toggle_group.bind("history"))
	fold.name="GrowthHistoryToggle"
	Disclosure.apply(fold,"完成记录",history_open,completed.size())
	var content:=VBoxContainer.new();content.name="GrowthHistory";content.visible=history_open;box.add_child(content)
	for goal: Dictionary in completed:u._text_to(content,"✓ "+str(goal.display_name),13).add_theme_color_override("font_color",UISkin.MUTED)

func _toggle_group(group: String) -> void:
	if not _current():return
	var content: Control=box.find_child("GrowthRoutes" if group=="routes" else "GrowthHistory",true,false) as Control
	var toggle: Button=box.find_child("GrowthRoutesToggle" if group=="routes" else "GrowthHistoryToggle",true,false) as Button
	var focus: Control=u.root.get_viewport().gui_get_focus_owner()
	if is_instance_valid(content) and content.visible and is_instance_valid(focus) and content.is_ancestor_of(focus) and is_instance_valid(toggle):toggle.grab_focus()
	if group=="routes":routes_open=not routes_open
	else:history_open=not history_open
	_rebuild()

func _update_values() -> void:
	if is_instance_valid(values) and not selected_stage.is_empty():
		var result: Dictionary=u.gameplay.growth.progress(selected_stage)
		values.text="当前 · %d / %d" % [int(result.current),int(result.target)]
		var parts: PackedStringArray=[]
		if not str(result.note).is_empty():parts.append(str(result.note))
		var index: int=choices.selected if is_instance_valid(choices) else 0
		if index>=0 and index<paths.size():parts.append(u.gameplay.growth.activity_status(paths[index]))
		note.text="\n".join(parts);note.visible=not note.text.is_empty()
	if not preview_fields.is_empty() and is_instance_valid(preview_fields.label):
		var result: Dictionary=u.gameplay.growth.progress(preview_fields.stage)
		preview_fields.label.text=("已达成 · " if result.complete else "规划 · ")+"%d / %d" % [int(result.current),int(result.target)]+("\n"+str(result.note) if not str(result.note).is_empty() else "")

func tick() -> void:
	if not _current():return
	var now: int=Time.get_ticks_msec()
	if now-last_poll_ms<250:return
	last_poll_ms=now
	var stage: Dictionary=_recommended()
	var available: Array[Dictionary]=_current_paths(stage)
	if _view_signature(stage,available)!=signature:_rebuild()
	else:_update_values()
