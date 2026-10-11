extends "roles_upgrade_fixture_v32.gd"
## Executes solely inside the verified v0.24 package, with real old-rule escrow
## and an already accepted campaign in addition to the inherited paid jobs.
func finish() -> void:
	if g!=null and state!=null and failures.is_empty():
		var freight: RefCounted=g.get("consignments")
		if check(freight!=null and store.catalog.table_names.has("consignment_defs") and not store.catalog.table_names.has("civilization_command_defs"),"actual old package has roles and no commander qualification"):
			var row: RefCounted=freight.instance("freight_anchor_echo")
			check(apply("consignment_action",row.contract_id,2,"dispatch:"+str(row.generation)),"actual v0.24 keeps paid entrusted cargo in flight custody")
			var faction: String="faction_route_council"
			var member: RefCounted=g.civilizations.membership();member.has_faction_id=true;member.faction_id=faction
			g.civilizations._add_reputation(faction,2600)
			var capital: Dictionary=g.definition("civilization_defs","faction_id",faction)
			var station: Dictionary=g.definition("station_defs","station_id",capital.capital_station_id)
			place(station.station_anchor_id,station.station_id)
			var war: String=""
			for spec: Dictionary in g.rows("civilization_war_defs"):
				if spec.faction_id==faction:war=spec.war_id;break
			check(apply("start_war",war),"actual v0.24 accepts a real old-rule active fleet campaign")
			check(store.save(state,"manual",2),"actual old escrow research orders and active campaign seal "+store.last_error)
	await super.finish()
