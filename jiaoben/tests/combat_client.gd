extends SceneTree
## Real physics integration; fixture positioning does not claim natural campaign completion.
const Main = preload("res://runtime/main.gd")
const T = preload("res://contracts/contract_types.gd")
const D = preload("res://contracts/contract_dtos.gd")
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures.append(label)
func _initialize() -> void:
	call_deferred("_run")
func body_at(parent: Node3D, point: Vector3, size: Vector3, id: String = "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 3
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = point
	if not id.is_empty(): body.set_meta("entity_id", id)
	return body
func _hit(id: String, raw: Vector3, point: Vector3, owner: String) -> void:
	hits.append({"id":id,"raw":raw,"point":point,"owner":owner})
func _run() -> void:
	var path := ProjectSettings.globalize_path("res://../jiaoben/tmp/combat-client.db")
	DirAccess.remove_absolute(path)
	var host := Main.new()
	host.progress_database_path = path
	root.add_child(host)
	await process_frame
	check(host.services_ready, "combat client database ready")
	await host._command("new_world", "物理集成验收", 1, "")
	host.busy = true
	var arena := Node3D.new()
	root.add_child(arena)
	var shots := XJProjectiles.new()
	arena.add_child(shots)
	shots.setup(host.store.catalog)
	shots.hit.connect(_hit)
	var origin := Vector3(50000,0,0)
	var shooter := body_at(arena,origin,Vector3.ONE*20,"owner")
	var blocker := body_at(arena,origin+Vector3(50,0,0),Vector3.ONE*10)
	var target := body_at(arena,origin+Vector3(200,0,0),Vector3(140,80,80),"large-target")
	await physics_frame
	await physics_frame
	shots.fire("owner",shooter.get_rid(),origin,Vector3.RIGHT,20000,500,Vector3(11,13,17))
	shots.simulate(0.02)
	check(hits.is_empty() and shots.active.is_empty(), "swept high-speed projectile stops at first solid obstruction")
	check(not host.world.line_of_sight(origin,target.position,shooter.get_rid(),"large-target"), "work/AI line of sight rejects intervening solid")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	check(host.world.line_of_sight(origin,target.position,shooter.get_rid(),"large-target"), "large target hull surface accepted by entity identity")
	shots.fire("owner",shooter.get_rid(),origin,Vector3.RIGHT,20000,500,Vector3(11,13,17))
	shots.simulate(0.02)
	check(hits.size()==1 and hits[0].id=="large-target" and hits[0].owner=="owner", "owner excluded and first actual target receives swept hit")
	check(hits.size()==1 and hits[0].raw==Vector3(11,13,17), "three raw damage components survive physical collision")
	shots.fire("owner",shooter.get_rid(),origin,Vector3.RIGHT,0,500,Vector3(3,5,7))
	check(hits.size()==2 and hits[1].id=="large-target", "instantaneous ray obeys same collision semantics")
	shots.fire("owner",shooter.get_rid(),origin,Vector3.LEFT,20000,50,Vector3.ONE)
	shots.simulate(0.02)
	check(shots.active.is_empty() and hits.size()==2, "projectile lifetime ends at database weapon range")
	arena.queue_free()
	await process_frame
	# AI instance fixture uses an unmodified reviewed archetype and its configured home.
	host.gameplay.act("undock")
	var npc := D.NpcStateDto.new()
	npc.npc_instance_id="physics-fixture-npc"
	npc.spawn_id="spawn_anchor_tutorial_scout"
	npc.sector_id=host.state.current_sector()
	npc.alive=true
	npc.shield=60; npc.armor=80; npc.hull=100
	npc.behavior_phase=T.NpcPhase.PATROL
	var home: Vector3=host.world.anchor_position("anchor_anchor_tutorial_scout")
	npc.pos_x=home.x; npc.pos_y=home.y; npc.pos_z=home.z
	host.state.add("npc_state",npc)
	host.world.sync_entities()
	var enemy: CharacterBody3D=host.world.npcs[npc.npc_instance_id]
	var player:=host.world.flight
	player.position=home+Vector3(0,0,-150)
	player.velocity=Vector3.ZERO
	player.write_back()
	enemy.quaternion=Quaternion.IDENTITY
	await physics_frame
	await physics_frame
	host.world.simulate_npcs(1.0/60.0)
	check(npc.behavior_phase==T.NpcPhase.ACQUIRE, "NPC detection enters reaction before first shot")
	check(not host.gameplay.save_eligible(), "acquire already blocks persistence and gate stable boundary")
	var behavior: Dictionary=host.store.catalog.one("npc_behavior_defs","behavior_id","behavior_scout")
	host.world.simulate_npcs(float(behavior.reaction_s)+0.01)
	check(npc.behavior_phase==T.NpcPhase.PURSUE, "reaction countdown advances into pursuit")
	enemy.quaternion=Quaternion.IDENTITY
	host.world.simulate_npcs(1.0/60.0)
	check(npc.behavior_phase==T.NpcPhase.ATTACK and host.world.projectiles.active.size()>0, "NPC fires real projectile inside range and firing cone")
	var shield_before: float=player.record.shield
	host.world.projectiles.simulate(0.5)
	host._flush_damage()
	check(player.record.shield<shield_before, "NPC physical projectile settles authoritative player damage")
	var station: Dictionary=host.store.catalog.one("station_defs","station_id","station_anchor_port")
	player.position=host.world.anchor_position(station.station_anchor_id)
	player.write_back()
	await physics_frame
	host.world.simulate_npcs(1.0/60.0)
	check(npc.behavior_phase==T.NpcPhase.DISENGAGE, "NPC stops combat when target enters station protection")
	host.world.simulate_npcs(float(behavior.reaction_s)+0.01)
	check(npc.behavior_phase==T.NpcPhase.RETURN, "disengage reaction advances to return")
	enemy.position=home
	enemy.velocity=Vector3.ZERO
	host.world.simulate_npcs(1.0/60.0)
	check(npc.behavior_phase==T.NpcPhase.PATROL, "return restores patrol at configured home radius")
	host.gameplay.combat_remaining_s=0.0
	check(host.gameplay.save_eligible(), "stable patrol releases save qualification after combat delay")
	host.gameplay.damage_npc(npc.npc_instance_id,Vector3.ONE*10000)
	host.world.sync_entities()
	check(not npc.alive and not host.world.npcs.has(npc.npc_instance_id), "death removes only dead NPC physical projection")
	host.queue_free()
	await process_frame
	print("COMBAT_CLIENT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
