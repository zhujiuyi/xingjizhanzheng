"""Typed scenario authority and bounded local measurement rows."""
REASONS=('completed','partial','manual','timeout','ship_destroyed','target_lost','out_of_range','loadout_changed','departed','combat','environment','overheat','unknown','signal_lost','objective_failed')
PAGES=('station','ships','warehouse','fitting','market','industry','salvage','research','missions','map','pause','settings','civilizations','frontier','hire','consignments','ship_roles','fitting_analysis','sources','operations','drones','exploration','projects','expeditions','reports','trials','blockades')
STATES={
'trial_state':('trial_id',"""trial_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
phase TEXT NOT NULL DEFAULT 'available' CHECK(phase IN('available','accepted','active','ready','completed','failed','withdrawn')),
ship_instance_id TEXT,reference_cost INTEGER NOT NULL DEFAULT 0 CHECK(reference_cost>=0),loadout_signature TEXT NOT NULL DEFAULT '',
remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),effective_hp REAL NOT NULL DEFAULT 0 CHECK(effective_hp>=0),
paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),wins INTEGER NOT NULL DEFAULT 0 CHECK(wins>=0),
best_elapsed_s REAL NOT NULL DEFAULT 0 CHECK(best_elapsed_s>=0),best_cost INTEGER NOT NULL DEFAULT 0 CHECK(best_cost>=0),
cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),award_earned INTEGER NOT NULL DEFAULT 0 CHECK(award_earned IN(0,1))""",
"FOREIGN KEY(content_snapshot_id,trial_id) REFERENCES frozen_trial_defs(content_snapshot_id,trial_id)"),
'trial_result_state':('trial_id,generation',"""trial_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
outcome TEXT NOT NULL CHECK(outcome IN('completed','failed','withdrawn')),reason_code TEXT NOT NULL,
ship_def_id TEXT NOT NULL,reference_cost INTEGER NOT NULL CHECK(reference_cost>0),paid_credit INTEGER NOT NULL CHECK(paid_credit>0),
elapsed_s REAL NOT NULL CHECK(elapsed_s>=0),effective_hp REAL NOT NULL CHECK(effective_hp>=0),finished_tick INTEGER NOT NULL CHECK(finished_tick>=0)""",
"FOREIGN KEY(content_snapshot_id,trial_id) REFERENCES frozen_trial_defs(content_snapshot_id,trial_id),FOREIGN KEY(content_snapshot_id,ship_def_id) REFERENCES frozen_ship_defs(content_snapshot_id,ship_id)"),
'scenario_actor_state':('npc_instance_id',"""npc_instance_id TEXT NOT NULL,spawn_id TEXT NOT NULL,
scenario_kind TEXT NOT NULL CHECK(scenario_kind IN('trial','blockade')),scenario_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
actor_role TEXT NOT NULL CHECK(actor_role IN('target','escort','patient','raider','relay'))""",
"FOREIGN KEY(snapshot_id,world_id,content_snapshot_id,npc_instance_id) REFERENCES npc_state(snapshot_id,world_id,content_snapshot_id,npc_instance_id),FOREIGN KEY(content_snapshot_id,spawn_id) REFERENCES frozen_npc_spawn_defs(content_snapshot_id,spawn_id)"),
'tactical_award_state':('award_id',"""award_id TEXT NOT NULL,selected INTEGER NOT NULL DEFAULT 0 CHECK(selected IN(0,1)),earned_tick INTEGER NOT NULL CHECK(earned_tick>=0)""",
"FOREIGN KEY(content_snapshot_id,award_id) REFERENCES frozen_tactical_award_defs(content_snapshot_id,award_id)"),
'blockade_state':('blockade_id',"""blockade_id TEXT NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),
phase TEXT NOT NULL DEFAULT 'available' CHECK(phase IN('available','accepted','active','ready','claimed','failed','withdrawn')),
payload_ship_id TEXT,loaded_units INTEGER NOT NULL DEFAULT 0 CHECK(loaded_units>=0),cargo_units INTEGER NOT NULL DEFAULT 0 CHECK(cargo_units>=0),
completed_units INTEGER NOT NULL DEFAULT 0 CHECK(completed_units>=0),lost_units INTEGER NOT NULL DEFAULT 0 CHECK(lost_units>=0),jettisoned_units INTEGER NOT NULL DEFAULT 0 CHECK(jettisoned_units>=0),
remaining_s REAL NOT NULL DEFAULT 0 CHECK(remaining_s>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0),
alerted INTEGER NOT NULL DEFAULT 0 CHECK(alerted IN(0,1)),bypass_remaining_s REAL NOT NULL DEFAULT 0 CHECK(bypass_remaining_s>=0),damage_debt_hp REAL NOT NULL DEFAULT 0 CHECK(damage_debt_hp>=0),
scan_node_index INTEGER,scan_remaining_s REAL NOT NULL DEFAULT 0 CHECK(scan_remaining_s>=0),
paid_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(paid_credit_total>=0),reward_credit_total INTEGER NOT NULL DEFAULT 0 CHECK(reward_credit_total>=0),rewarded_units_total INTEGER NOT NULL DEFAULT 0 CHECK(rewarded_units_total>=0),
cooldown_remaining_s REAL NOT NULL DEFAULT 0 CHECK(cooldown_remaining_s>=0),award_earned INTEGER NOT NULL DEFAULT 0 CHECK(award_earned IN(0,1))""",
"FOREIGN KEY(content_snapshot_id,blockade_id) REFERENCES frozen_blockade_defs(content_snapshot_id,blockade_id),FOREIGN KEY(content_snapshot_id,blockade_id,scan_node_index) REFERENCES frozen_blockade_node_defs(content_snapshot_id,blockade_id,node_index)"),
'blockade_node_state':('blockade_id,node_index',"""blockade_id TEXT NOT NULL,node_index INTEGER NOT NULL,generation INTEGER NOT NULL DEFAULT 0 CHECK(generation>=0),completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN(0,1))""",
"FOREIGN KEY(content_snapshot_id,blockade_id,node_index) REFERENCES frozen_blockade_node_defs(content_snapshot_id,blockade_id,node_index)"),
'blockade_result_state':('blockade_id,generation',"""blockade_id TEXT NOT NULL,generation INTEGER NOT NULL CHECK(generation>=1),
outcome TEXT NOT NULL CHECK(outcome IN('claimed','failed','withdrawn')),reason_code TEXT NOT NULL,
loaded_units INTEGER NOT NULL CHECK(loaded_units>=0),delivered_units INTEGER NOT NULL CHECK(delivered_units>=0),lost_units INTEGER NOT NULL CHECK(lost_units>=0),jettisoned_units INTEGER NOT NULL CHECK(jettisoned_units>=0),
paid_credit INTEGER NOT NULL CHECK(paid_credit>0),reward_credit INTEGER NOT NULL CHECK(reward_credit>=0),elapsed_s REAL NOT NULL CHECK(elapsed_s>=0),finished_tick INTEGER NOT NULL CHECK(finished_tick>=0),
CHECK(loaded_units=delivered_units+lost_units+jettisoned_units)""",
"FOREIGN KEY(content_snapshot_id,blockade_id) REFERENCES frozen_blockade_defs(content_snapshot_id,blockade_id)"),
'telemetry_source_state':('item_id,source_kind',"""item_id TEXT NOT NULL,source_kind TEXT NOT NULL CHECK(source_kind IN('mining','manufacture','mission','salvage','purchase')),units INTEGER NOT NULL CHECK(units>0)""",
"FOREIGN KEY(content_snapshot_id,item_id) REFERENCES frozen_item_defs(content_snapshot_id,item_id)"),
'activity_record_state':('record_id',"""record_id TEXT NOT NULL,activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','exploration','operation','trial','blockade','ship_loss')),
object_id TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN('active','finished')),outcome TEXT NOT NULL DEFAULT '' CHECK(outcome IN('','completed','partial','failed','withdrawn','destroyed')),
reason_code TEXT NOT NULL DEFAULT '',partial_baseline INTEGER NOT NULL DEFAULT 0 CHECK(partial_baseline IN(0,1)),
started_tick INTEGER NOT NULL CHECK(started_tick>=0),finished_tick INTEGER NOT NULL DEFAULT 0 CHECK(finished_tick>=0),elapsed_s REAL NOT NULL DEFAULT 0 CHECK(elapsed_s>=0)""",''),
'telemetry_menu_state':('page_id',"""page_id TEXT NOT NULL,duration_s REAL NOT NULL DEFAULT 0 CHECK(duration_s>=0),visits INTEGER NOT NULL DEFAULT 0 CHECK(visits>=0)""",''),
'telemetry_timing_state':('singleton',"""singleton INTEGER NOT NULL CHECK(singleton=1),navigation_wait_s REAL NOT NULL DEFAULT 0 CHECK(navigation_wait_s>=0)""",''),
'activity_total_state':('activity_kind,outcome,reason_code',"""activity_kind TEXT NOT NULL CHECK(activity_kind IN('mission','exploration','operation','trial','blockade','ship_loss')),
outcome TEXT NOT NULL CHECK(outcome IN('completed','partial','failed','withdrawn','destroyed')),reason_code TEXT NOT NULL,
occurrences INTEGER NOT NULL CHECK(occurrences>0),elapsed_s REAL NOT NULL CHECK(elapsed_s>=0)""",'')
}
for _table,(_key,_columns,_foreign) in list(STATES.items()):
 if 'reason_code TEXT' in _columns:
  _allowed=('',)+REASONS if _table=='activity_record_state' else REASONS
  _columns=_columns.replace('reason_code TEXT NOT NULL',"reason_code TEXT NOT NULL CHECK(reason_code IN("+','.join(repr(v) for v in _allowed)+"))")
 if _table=='telemetry_menu_state':
  _columns=_columns.replace('page_id TEXT NOT NULL',"page_id TEXT NOT NULL CHECK(page_id IN("+','.join(repr(v) for v in PAGES)+"))")
 STATES[_table]=(_key,_columns,_foreign)
