extends VBoxContainer
## Observed coordinates stay frozen; a live contact is independently validated.
var u: Node
var original: RefCounted
var generation: int
var elapsed: float=0.0
var signature: String=""
var page: int=0
var body: VBoxContainer
var build: int=0
var readouts: Array[Dictionary]=[]
func setup(ui: Node) -> void:
	u=ui;original=u.state;generation=u.business_generation;name="AuxiliaryIntelPanel";add_theme_constant_override("separation",6)
	u._text_to(self,"侦察情报 · 失联后只保留上次位置",16);body=VBoxContainer.new();add_child(body);_update()
func current() -> bool:return not is_queued_for_deletion() and is_instance_valid(u) and u.state==original and u.business_generation==generation and u.page=="drones"
func _change_page(direction: int,built: int) -> Callable:
	var reference: WeakRef=weakref(self)
	return func():
		var view: Node=reference.get_ref() as Node
		if not is_instance_valid(view) or not view.current() or view.build!=built:return
		view.page+=direction;view._update()
func _locate(record: RefCounted,built: int) -> Callable:
	var reference: WeakRef=weakref(self)
	return func():
		var view: Node=reference.get_ref() as Node
		if not is_instance_valid(view) or not view.current() or view.build!=built or not view.u.gameplay.auxiliary_drones.current(record):return
		var id: String=view.u.sector.auxiliary_marker(record)
		if not id.is_empty():view.u.show_page("");view.u._select_target(id)
func _update() -> void:
	var records: Array=u.state.rows("auxiliary_intel_state").duplicate();records.sort_custom(func(a: RefCounted,b: RefCounted):return a.observed_tick>b.observed_tick)
	var pages: int=maxi(1,int(ceil(float(records.size())/8.0)));page=clampi(page,0,pages-1)
	var visible: Array=records.slice(page*8,mini(records.size(),page*8+8));var ids: Array=[page,records.size()]
	for record: RefCounted in visible:ids.append(record.owner_ship_id+":"+record.target_kind+":"+record.target_id)
	var wanted: String=JSON.stringify(ids)
	if wanted==signature:_refresh_readouts();return
	signature=wanted;build+=1;var built: int=build;readouts.clear()
	for child: Node in body.get_children():body.remove_child(child);child.queue_free()
	if records.is_empty():u._text_to(body,"侦察无人机会记录自身传感器范围内的目标。",13);return
	var paging:=HFlowContainer.new();body.add_child(paging)
	for pair: Array in [["上一页",-1],["下一页",1]]:
		var direction: int=pair[1];var button: Button=u._button(paging,pair[0],_change_page(direction,built))
		button.disabled=page+direction<0 or page+direction>=pages
	u._text_to(paging,"%d项 · %d/%d页" % [records.size(),page+1,pages],13)
	for record: RefCounted in visible:
		var line:=HFlowContainer.new();body.add_child(line)
		var label: Label=u._text_to(line,"",13);label.name="IntelReadout_"+record.target_id.validate_node_name()
		var marker: Button=u._button(line,"定位上次位置",_locate(record,built))
		marker.name="AuxiliaryLocate_"+record.target_id.validate_node_name();readouts.append({"record":record,"label":label,"marker":marker})
	_refresh_readouts()
func _refresh_readouts() -> void:
	var service: RefCounted=u.gameplay.auxiliary_drones
	for readout: Dictionary in readouts:
		var record: RefCounted=readout.record;var valid: bool=service.current(record);var info: Dictionary=service.query(record.target_id)
		var live: bool=valid and not info.is_empty() and info.generation==record.target_generation and service.detected(record.target_id)
		var state: String="当前探测" if live else "上次观测" if valid else "已失效"
		readout.label.text="%s · %s · %.0f秒前%s" % [record.observed_label,state,service.age(record)," · 剩余 %d" % record.remaining_units if record.target_kind=="resource" else ""]
		var position: Vector3=Vector3(record.pos_x,record.pos_y,record.pos_z)
		readout.marker.disabled=not valid;readout.marker.tooltip_text="%s；这里记录的是观测坐标" % XJSpaceUnits.distance(position.distance_to(u.gameplay.position(u.state.ship())))
func _process(delta: float) -> void:
	if not current():return
	elapsed+=delta
	if elapsed<1.0:return
	elapsed=0.0;_update()
