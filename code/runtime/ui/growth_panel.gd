extends RefCounted
const T=preload("res://contracts/contract_types.gd")
var u: Node
var faction: String=""
var selected_stage: Dictionary={}
var values: Label
var note: Label
var outcome: Label
var choices: OptionButton
var paths: Array[Dictionary]=[]

func build(ui: Node,selected_faction: String) -> void:
	u=ui;faction=selected_faction
	var growth: RefCounted=u.gameplay.growth
	if not growth.supported():return
	selected_stage=growth.selected(faction)
	if selected_stage.is_empty():return
	var box: VBoxContainer=VBoxContainer.new();box.name="GrowthPanel";u.body.add_child(box)
	u._text_to(box,"成长目标",18)
	var goals: Array[Dictionary]=growth.stages(faction)
	var select: OptionButton=OptionButton.new();select.name="GrowthStage";select.size_flags_horizontal=Control.SIZE_EXPAND_FILL;select.clip_text=true
	var current: int=0
	for index: int in range(goals.size()):
		select.add_item(str(goals[index].display_name))
		if goals[index].stage_id==selected_stage.stage_id:current=index
	select.select(current);box.add_child(select)
	var state: RefCounted=u.state;var catalog: RefCounted=u.catalog;var epoch: int=state.epoch;var generation: int=u.business_generation
	select.item_selected.connect(func(index: int):
		if u.state!=state or u.catalog!=catalog or state.epoch!=epoch or u.business_generation!=generation or u.page!="civilizations" or u.civilization_selected_faction!=faction:return
		if index>=0 and index<goals.size():u.requested.emit("growth_select",str(goals[index].stage_id),1,"")
	)
	values=u._text_to(box,"",14);values.name="GrowthValues"
	note=u._text_to(box,"",13);note.name="GrowthGap"
	outcome=u._text_to(box,"收益 · "+str(selected_stage.outcome_label),13)
	paths=growth.activities(selected_stage.stage_id)
	if not paths.is_empty():
		choices=OptionButton.new();choices.name="GrowthActivity";choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choices.clip_text=true
		for path: Dictionary in paths:choices.add_item(growth.activity_label(path))
		box.add_child(choices)
		var controls: HFlowContainer=HFlowContainer.new();box.add_child(controls)
		var weak_choices: WeakRef=weakref(choices)
		for action: String in ["growth_map","growth_navigate","growth_open"]:
			_add_action(controls,action,weak_choices,state,catalog,epoch,generation)
	tick()

func _add_action(parent: Node,action: String,weak_choices: WeakRef,state: RefCounted,catalog: RefCounted,epoch: int,generation: int) -> void:
	var callback: Callable=func():
		if u.state!=state or u.catalog!=catalog or state.epoch!=epoch or u.business_generation!=generation or u.page!="civilizations" or u.civilization_selected_faction!=faction:return
		var live: OptionButton=weak_choices.get_ref() as OptionButton
		if not is_instance_valid(live) or live.selected<0 or live.selected>=paths.size():return
		u.requested.emit(action,str(selected_stage.stage_id),1,str(paths[live.selected].activity_index))
	var title: String={"growth_map":"定位途径","growth_navigate":"前往","growth_open":"打开服务"}[action]
	var button: Button=u._button(parent,title,callback);button.name="Growth_"+action
	if action=="growth_navigate":button.disabled=u.state.ship().status!=T.ShipStatus.FLYING

func tick() -> void:
	if not is_instance_valid(values):return
	var result: Dictionary=u.gameplay.growth.progress(selected_stage)
	values.text=("已达成 · " if result.complete else "当前 · ")+"%d / %d" % [int(result.current),int(result.target)]
	note.text=str(result.note);note.visible=not note.text.is_empty()
