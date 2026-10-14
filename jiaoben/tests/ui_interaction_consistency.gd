extends "ui_quality_audit.gd"
## Fresh real Main. Funding, unlocks and inventory are declared UI fixtures.
## Valid operations use the real pointer/commands; stale/invalid signals are probes.
const InteractionCodec = preload("res://runtime/data/codec.gd")
const InteractionContract = preload("res://runtime/ui/ui_interaction.gd")
var request_events: Array[Dictionary] = []
var stale_control: Button

func _initialize() -> void:
	get_tree().set_meta("xj_ui_consistency_v61_diagnostic",true)
	create_timer(360.0).timeout.connect(func(): check(false,"interaction watchdog"); finish())
	_run.call_deferred()

func resources() -> String:
	var payload: Dictionary = {}
	for table: String in ["player_state","ship_state","container_state","inventory_stack_state","item_instance_state","equipment_state","specialization_progress_state","specialization_evidence_state","specialization_research_state"]:
		if not XJRuntimeState.TABLES.has(table): continue
		var values: Array[String] = []
		for row: RefCounted in host.state.rows(table): values.append(JSON.stringify(InteractionCodec.new().encode_row(table,row)))
		values.sort(); payload[table] = values
	return JSON.stringify(payload)

func show_interaction(page_name: String) -> void:
	host.ui.menu_open=false;host.ui.show_page(page_name);await frames(10)

func dirty_number(spin: SpinBox,raw: String) -> void:
	var node: Node=spin
	while node!=null:
		if node is ScrollContainer:node.ensure_control_visible(spin)
		node=node.get_parent()
	await frames(3)
	var editor: LineEdit=spin.get_line_edit()
	editor.grab_focus();editor.select_all();root.grab_focus();await frames(2)
	var clear: InputEventKey=InputEventKey.new();clear.keycode=KEY_BACKSPACE;clear.pressed=true;root.push_input(clear,true)
	for character: String in raw:
		var key_event: InputEventKey=InputEventKey.new();key_event.unicode=character.unicode_at(0);key_event.pressed=true;root.push_input(key_event,true)
	await frames(2)
	check(editor.text==raw,"real keyboard retains unsubmitted text "+JSON.stringify(raw))

func invalid_inputs(spin: SpinBox,button: Button,action: String) -> void:
	for raw: String in ["","0","-1","1.5","abc",str(int(spin.max_value)+1)]:
		await dirty_number(spin,raw)
		var before: String=resources();var count: int=request_events.size()
		check(button.disabled,"raw invalid quantity disables action "+action+" "+JSON.stringify(raw))
		button.pressed.emit();await frames(3)
		check(request_events.size()==count and resources()==before,"invalid quantity never submits a restored old value "+action+" "+JSON.stringify(raw))

func warehouse_case() -> void:
	await show_interaction("warehouse")
	var entry: Dictionary={}
	for candidate_row: Dictionary in host.ui.warehouse_panel.refs.station_rows:
		if candidate_row.get("amount") is SpinBox and candidate_row.amount.editable and candidate_row.held_quantity>=2 and not candidate_row.button.disabled:entry=candidate_row;break
	if not check(not entry.is_empty(),"real warehouse fixture exposes editable transferable stack"):return
	await invalid_inputs(entry.amount,entry.button,"warehouse")
	await dirty_number(entry.amount,"2")
	var count: int=request_events.size()
	if await actual_click(entry.button,"transfer unsubmitted quantity two"):
		await settle_writer("warehouse transfer")
		check(request_events.size()==count+1 and int(request_events[-1].quantity)==2,"real transfer submits exactly the unsubmitted integer")

func research_case() -> void:
	var balance: Dictionary=host.gameplay.specializations.balance
	var warehouse: String=host.gameplay.inventory.warehouse(host.gameplay.station())
	host.gameplay.inventory.grant(warehouse,str(balance.donation_item_id),int(balance.donation_units_per_point)*4)
	await show_interaction("research")
	var spin: SpinBox=host.ui.body.find_child("SpecializationQuantity",true,false) as SpinBox
	var donate: Button=host.ui.body.find_child("SpecializationDonate",true,false) as Button
	if not check(spin!=null and donate!=null,"real research controls exist"):return
	await invalid_inputs(spin,donate,"specialization_donate")
	await dirty_number(spin,"2")
	var before: int=host.gameplay.specializations.available()
	if await actual_click(donate,"donate unsubmitted analysis two"):
		await settle_writer("analysis donation")
		check(host.gameplay.specializations.available()==before+2,"real donation creates exactly two analysis points")
		check(str(request_events[-1].action)=="specialization_donate" and int(request_events[-1].quantity)==2,"research request uses current editor text")

func fitting_case() -> void:
	await show_interaction("fitting_analysis")
	var picker: OptionButton=host.ui.body.find_child("FittingCandidate",true,false) as OptionButton
	var slot_picker: OptionButton=host.ui.body.find_child("FittingSlot",true,false) as OptionButton
	var compare: Button=host.ui.body.find_child("FittingCalculate",true,false) as Button
	if not check(picker!=null and picker.item_count>=3 and slot_picker!=null,"real fitting fixture offers distinct candidate instances"):return
	for index: int in range(slot_picker.item_count):
		if str(slot_picker.get_item_metadata(index))=="utility:0":slot_picker.select(index);slot_picker.item_selected.emit(index);break
	picker.select(1);picker.item_selected.emit(1)
	if not await actual_click(compare,"calculate candidate A"):return
	var apply: Button=host.ui.body.find_child("FittingApply",true,false) as Button
	check(not apply.disabled,"candidate A has a real valid quoted replacement")
	picker.select(2);picker.item_selected.emit(2)
	var count: int=request_events.size();var before: String=resources()
	check(apply.disabled,"selecting candidate B invalidates A immediately")
	apply.pressed.emit();await frames(3)
	check(request_events.size()==count and resources()==before,"old A quote cannot apply after selecting B")
	await actual_click(compare,"calculate candidate B")
	# Programmatic selection without its signal still must fail the apply signature.
	picker.select(1);count=request_events.size();apply.pressed.emit();await frames(3)
	check(apply.disabled and request_events.size()==count,"apply independently verifies actual dropdown signature")

func focus_and_return_case() -> void:
	await show_interaction("market")
	var quote: Dictionary=host.ui.quotes[0]
	quote.amount.get_line_edit().grab_focus();await frames(3)
	check(root.gui_get_focus_owner()==quote.amount.get_line_edit(),"market refresh fixture actually holds exact quantity editor focus")
	check(host.ui._focus_controls(host.ui.body).has(quote.amount.get_line_edit()),"focus collection includes the real internal SpinBox editor")
	var row_id: String=str(quote.target)
	var saved_view: Dictionary=host.ui.capture_local_view(host.ui.body)
	print("UI_INTERACTION_FOCUS_BEFORE ",JSON.stringify({"owner":str(root.gui_get_focus_owner().get_path()) if root.gui_get_focus_owner()!=null else "","row":row_id,"key":saved_view.key,"editor":saved_view.editor,"spin_focus_mode":quote.amount.focus_mode,"editor_focus_mode":quote.amount.get_line_edit().focus_mode,"editor_is_internal":not quote.amount.get_children().has(quote.amount.get_line_edit()),"generation":host.ui.business_generation}))
	host.ui.refresh_page();await frames(12)
	var current_focus: Control=root.gui_get_focus_owner()
	var restored: bool=false
	for current_quote: Dictionary in host.ui.quotes:
		if str(current_quote.target)==row_id:
			check(host.ui._focus_controls(host.ui.body).has(current_quote.amount.get_line_edit()),"reconstructed internal quantity editor remains in the focus chain")
			restored=current_focus==current_quote.amount.get_line_edit()
	print("UI_INTERACTION_FOCUS_AFTER ",JSON.stringify({"owner":str(current_focus.get_path()) if current_focus!=null else "","row":row_id,"current_key":host.ui._focus_key(current_focus,host.ui.body) if current_focus!=null else "","saved_key":saved_view.key,"generation":host.ui.business_generation,"restored":restored}))
	check(restored,"market refresh restores exact row quantity editor focus")
	await show_interaction("fitting_analysis")
	check(host.ui.panel.find_child("PanelHome",true,false)!=null,"subpage preserves explicit home exit")
	await actual_click(host.ui.panel.find_child("PanelClose",true,false) as Button,"return analysis to parent")
	check(host.ui.page=="fitting","analysis returns to fitting parent")
	await show_interaction("industry");host.ui.open_sources("material_structural_stock");await frames(10)
	await actual_click(host.ui.panel.find_child("PanelClose",true,false) as Button,"return sources to real origin")
	check(host.ui.page=="industry","source back resolves the actual origin service")

func blur_case() -> void:
	await show_interaction("market")
	if not check(host.ui.quotes.size()>=2,"blur fixture provides two independent market editors"):return
	var first: Dictionary=host.ui.quotes[0]
	var second: Dictionary=host.ui.quotes[1]
	for raw: String in ["2","",str(int(first.amount.max_value)+1)]:
		await dirty_number(first.amount,raw)
		var count: int=request_events.size();var before: String=resources()
		second.amount.get_line_edit().grab_focus();await frames(8)
		var visible_quantity: int=host.ui._business_row_quantity(first)
		var expected_price: int=int(host.gameplay.economy.quote(str(first.id),visible_quantity,false)) if visible_quantity>0 else 0
		check(request_events.size()==count and resources()==before,"real SpinBox focus-exit normalization never requests a transaction "+JSON.stringify(raw))
		check(str(first.total_label.text)==str(expected_price) if visible_quantity>0 else str(first.total_label.text)=="—","post-blur price follows the currently visible integer or invalid marker "+JSON.stringify(raw))
		check(str(first.quantity_label.text)==(str(visible_quantity) if visible_quantity>0 else "—"),"post-blur quantity display follows actual editor normalization")
		var stock: RefCounted=host.ui._business_stock(str(first.id))
		var allowed: bool=visible_quantity>0 and stock!=null and stock.quantity>=visible_quantity and host.state.player().credit>=expected_price and host.ui._service_reason("trade").is_empty()
		print("UI_INTERACTION_BLUR_WITNESS ",JSON.stringify({"raw_before":raw,"raw_after":first.amount.get_line_edit().text,"quantity":visible_quantity,"stock":stock.quantity if stock!=null else -1,"credit":host.state.player().credit,"price":expected_price,"disabled":first.button.disabled,"status":first.status_label.text,"allowed":allowed}))
		check(first.button.disabled==(not allowed),"post-blur actionable state matches actual stock credit service and visible quantity")
		if visible_quantity>0 and stock!=null and visible_quantity>stock.quantity:check(first.status_label.text.contains("库存"),"normalized quantity beyond actual stock explains the real blocker")
	await show_interaction("warehouse")
	var editable_rows: Array[Dictionary]=[]
	for row: Dictionary in host.ui.warehouse_panel.refs.station_rows:
		if row.get("amount") is SpinBox and row.amount.editable:editable_rows.append(row)
	if not check(editable_rows.size()>=2,"warehouse blur has two real row editors"):return
	var row: Dictionary=editable_rows[0]
	await dirty_number(row.amount,"")
	var count: int=request_events.size();var before: String=resources()
	editable_rows[1].amount.get_line_edit().grab_focus();await frames(8)
	var normalized: int=InteractionContract.integer_input(row.amount)
	var quote: Dictionary=host.gameplay.inventory.quote_transfer(str(row.kind),str(row.id),normalized,str(row.destination)) if normalized>0 else {"ok":false}
	check(request_events.size()==count and resources()==before,"warehouse native blur changes no authority or request")
	check(row.button.disabled==(not bool(quote.ok)),"warehouse qualification follows the normalized visible editor")

func queued_view_case() -> void:
	await show_interaction("market")
	var count: int=request_events.size();var before: String=resources()
	host.ui.refresh_page();host.ui.refresh_page()
	var definitions: Array=host.gameplay.rows("mission_defs")
	if not definitions.is_empty():host.ui.show_mission(str(definitions[0].mission_id))
	host.ui.show_page("warehouse")
	for row: Dictionary in host.ui.warehouse_panel.refs.station_rows:
		if row.get("amount") is SpinBox and row.amount.editable:row.amount.get_line_edit().grab_focus();break
	host.ui.refresh_page();host.ui.show_page("reports")
	await frames(12)
	check(host.ui.page=="reports" and request_events.size()==count and resources()==before,"queued restore mission-focus and warehouse-reveal survive consecutive page destruction")
	var token: Dictionary=InteractionContract.context(host.ui)
	var detached: Control=Control.new();root.add_child(detached)
	check(not InteractionContract.current(host.ui,token,detached),"same-generation control outside current page is rejected")
	detached.free()
	var freed_control: Variant=Control.new();freed_control.free()
	check(not InteractionContract.current(host.ui,token,freed_control),"freed witness reaches Variant validity guard without typed conversion")
	var freed_owner: Variant=Node.new();freed_owner.free()
	check(not InteractionContract.current(freed_owner,{},null),"freed UI owner reaches validity guard without member access")

func navigation_case() -> void:
	await show_interaction("operations")
	for node: Node in descendants(host.ui.body):
		if node is Button and str(node.name).begins_with("OperationNavigate_"):
			check(node.disabled and node.tooltip_text.contains("出港"),"docked operation travel has explicit blocked reason")
	await show_interaction("consignments")
	for node: Node in descendants(host.ui.body):
		if node is Button and str(node.name).begins_with("FreightRoute_"):
			check(node.disabled and node.tooltip_text.contains("出港"),"docked freight travel never silently becomes map")

func stale_case() -> void:
	await show_interaction("ships")
	stale_control=host.ui._command(host.ui.body,"旧页面维修探针","repair",host.state.ship().ship_instance_id)
	stale_control.get_parent().remove_child(stale_control);root.add_child(stale_control);stale_control.hide()
	await show_interaction("warehouse")
	var count: int=request_events.size();var before: String=resources()
	stale_control.pressed.emit();await frames(3)
	check(request_events.size()==count and resources()==before,"retained old page command is rejected")
	await host._command("new_world","交互一致性第二世界",1,"");await settle_writer("second real world")
	host.set_process(false);host.set_physics_process(false)
	count=request_events.size();before=resources();stale_control.pressed.emit();await frames(3)
	check(request_events.size()==count and resources()==before,"retained old world command is rejected")
	stale_control.queue_free();stale_control=null

func disposed_navigation_case() -> void:
	var world: XJSector=host.world
	var hud: XJNavigationHUD=host.ui.navigation_hud
	var target_id: String=""
	for id: String in world.targets:
		if world.target_is_local(id) and is_finite(world.target_distance(id)):target_id=id;break
	if not check(not target_id.is_empty() and world.navigation_queries_ready(),"live world retains normal local finite navigation queries"):return
	hud.configure(world,host.camera,host.store.catalog);hud.selected_id=target_id;hud.show();hud.refresh()
	check(hud._world_ready(),"live navigation HUD accepts its active business binding")
	var before: String=resources()
	# Reproduce Main teardown: RefCounted gameplay and the world Node still
	# exist, but dispose has severed their services before queued HUD drawing.
	host.gameplay.dispose()
	check(is_instance_valid(world) and is_instance_valid(host.gameplay) and not world.navigation_queries_ready(),"disposed business is rejected while its world Node is still alive")
	check(not world.target_is_local(target_id) and world.target_site(target_id).is_empty(),"disposed local and site queries fail closed")
	check(is_inf(world.target_distance(target_id)) and world.target_direction(target_id)==Vector3.ZERO and world.target_components(target_id).is_empty(),"disposed distance direction and component queries return safe absence")
	check(not world.contact_visible(world.targets[target_id],0.0),"disposed contacts are unavailable")
	check(hud.target_geometry().is_empty() and hud.marker_geometry().is_empty(),"HUD refuses queued geometry from disposed services")
	hud.queue_redraw();hud.radar.queue_redraw();hud.refresh();hud.update_annotations();await frames(4)
	check(hud.contacts.is_empty() and not hud.target_caption.visible and resources()==before,"queued cleanup draw leaves no stale contact or authoritative mutation")

func _run() -> void:
	directory=OS.get_environment("XJ_UI_INTERACTION_DIRECTORY").replace("\\","/")
	if not check(fresh_external_directory("ui_interaction_consistency.gd","ui-interaction"),"fresh scoped interaction database required"):await finish();return
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);root.content_scale_size=root.size
	host=Main.new();host.progress_database_path=directory.path_join("progress.db");root.add_child(host);await frames(8)
	if not check(host.services_ready and host.state==null,"real Main initializes without personal save"):await finish();return
	await host._command("new_world","交互一致性专项",1,"");await settle_writer("new world")
	label="interaction";await fixture()
	var existing_hulls: Array[String]=[]
	for ship: RefCounted in host.state.rows("ship_state"):existing_hulls.append(ship.ship_instance_id)
	await host._command("buy_ship","cruiser_horizon",1,"");await settle_writer("paid fitting fixture hull")
	var purchased_id: String=""
	for ship: RefCounted in host.state.rows("ship_state"):
		if not existing_hulls.has(ship.ship_instance_id):purchased_id=ship.ship_instance_id;break
	if not check(not purchased_id.is_empty(),"real paid purchase provides an unprotected fitting hull"):await finish();return
	await host._command("switch_ship",purchased_id,1,"");await settle_writer("actual switch to fixture hull")
	host.set_process(false);host.set_physics_process(false)
	host.ui.requested.connect(func(action: String,target_id: String,amount: int,extra: String):request_events.append({"action":action,"target":target_id,"quantity":amount,"extra":extra}))
	await warehouse_case();await research_case();await fitting_case();await blur_case();await focus_and_return_case();await queued_view_case();await navigation_case();await stale_case();await disposed_navigation_case()
	await finish()

func finish() -> void:
	if finishing:return
	finishing=true
	if is_instance_valid(stale_control):stale_control.queue_free()
	if is_instance_valid(host):host.queue_free()
	host=null;await frames(6)
	var summary: Dictionary={"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures.size(),"failure_labels":failures,"interaction_checks":interaction_checks,"fixtures":["fresh UUID real Main database","credit=1000000","all catalog unlocks","named inventory grants","actual paid cruiser purchase and switch","catalog-derived material donation stock"],"scope":"quantity editor, fitting quote, context, focus, parent return and docked navigation; not natural progression or full combat"}
	var file: FileAccess=FileAccess.open(directory.path_join("result.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(summary,"\t")+"\n");file.close()
	print("UI_INTERACTION_RESULT ",summary.result," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
