CREATE TRIGGER fleet_seal_validation BEFORE UPDATE OF status ON save_snapshot
WHEN NEW.status='sealed' AND OLD.status='building' AND EXISTS(SELECT 1 FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
BEGIN
 SELECT CASE WHEN
 (SELECT count(*) FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id)<>(SELECT count(*) FROM frozen_crew_profile_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM fleet_total_state WHERE snapshot_id=NEW.snapshot_id)<>1 OR
 (SELECT count(*) FROM crew_member_state WHERE snapshot_id=NEW.snapshot_id AND phase<>'available')>(SELECT max_recruited_crew FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id) OR
 (SELECT count(*) FROM fleet_deployment_state WHERE snapshot_id=NEW.snapshot_id AND phase IN('deployed','retreating','returning'))>(SELECT max_owned_companions FROM frozen_fleet_balance_defs WHERE content_snapshot_id=NEW.content_snapshot_id)
 THEN RAISE(ABORT,'fleet roster coverage or capacity invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_member_state c JOIN frozen_crew_profile_defs p USING(content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs j USING(content_snapshot_id,profession_id) JOIN frozen_fleet_balance_defs b USING(content_snapshot_id)
 WHERE c.snapshot_id=NEW.snapshot_id AND
 (c.hire_paid_credit<>c.generation*j.hire_fee_credit OR c.experience>b.experience_cap OR
 c.contribution_total>b.experience_cap*j.contribution_per_xp OR c.experience<>min(b.experience_cap,CAST(c.contribution_total/j.contribution_per_xp AS INTEGER)) OR
 abs(c.contribution_remainder-(c.contribution_total-c.experience*j.contribution_per_xp))>0.00001 OR
 c.salary_elapsed_s>=b.salary_period_s OR c.unpaid_periods>b.arrears_period_limit OR
 (c.generation>0 AND NOT EXISTS(SELECT 1 FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id AND c.salary_period_credit=CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER))) OR
 c.salary_paid_credit+c.arrears_credit>c.salary_periods*(SELECT max(CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER)) FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id) OR
 c.arrears_credit>c.unpaid_periods*(SELECT max(CAST(j.salary_credit*r.salary_multiplier+0.999999 AS INTEGER)) FROM frozen_crew_rank_defs r WHERE r.content_snapshot_id=c.content_snapshot_id AND r.profession_id=p.profession_id) OR
 c.salary_periods*b.salary_period_s>NEW.simulation_tick/(SELECT coalesce(value_real,value_integer) FROM frozen_rule_parameters WHERE content_snapshot_id=c.content_snapshot_id AND parameter_id='simulation_hz')+0.00001 OR
 c.treatment_paid_credit%b.injury_treatment_credit<>0 OR c.rest_paid_credit%b.rest_credit<>0 OR
 (c.phase<>'available' AND c.generation=0) OR
 (c.generation=0 AND (c.experience<>0 OR c.contribution_total<>0 OR c.loyalty<>b.loyalty_initial OR c.salary_paid_credit<>0 OR c.salary_periods<>0 OR c.arrears_credit<>0 OR c.rest_paid_credit<>0 OR c.treatment_paid_credit<>0)) OR
 (c.phase IN('injured','resting') AND (c.recovery_remaining_s<=0 OR c.recovery_remaining_s>CASE c.phase WHEN 'injured' THEN b.injury_recovery_s ELSE b.rest_duration_s END OR c.station_id IS NULL)) OR
 (c.phase NOT IN('injured','resting') AND c.recovery_remaining_s<>0) OR
 (c.phase='available' AND c.station_id IS NOT NULL) OR
 (c.phase<>'available' AND c.station_id IS NULL AND NOT EXISTS(SELECT 1 FROM crew_assignment_state a WHERE a.snapshot_id=c.snapshot_id AND a.profile_id=c.profile_id))))
 THEN RAISE(ABORT,'crew career payment timing or recovery invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_assignment_state a JOIN crew_member_state c USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profile_defs p USING(content_snapshot_id,profile_id) JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 JOIN frozen_fleet_hull_defs h ON h.content_snapshot_id=s.content_snapshot_id AND h.ship_id=s.ship_def_id
 WHERE a.snapshot_id=NEW.snapshot_id AND (c.phase<>'hired' OR c.station_id IS NOT NULL OR a.profession_id<>p.profession_id OR
 s.policy_id<>'normal_owned' OR s.status NOT IN('docked','flying') OR a.assigned_tick>NEW.simulation_tick OR
 (SELECT count(*) FROM crew_assignment_state other WHERE other.snapshot_id=a.snapshot_id AND other.ship_instance_id=a.ship_instance_id)>h.crew_slots))
 THEN RAISE(ABORT,'crew assignment owner profession or capacity invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_support_quote_state q JOIN crew_member_state member USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profile_defs profile USING(content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs profession ON profession.content_snapshot_id=q.content_snapshot_id AND profession.profession_id=q.profession_id
 JOIN frozen_crew_rank_defs rank ON rank.content_snapshot_id=q.content_snapshot_id AND rank.profession_id=q.profession_id AND rank.rank=q.rank_at_payment
 JOIN frozen_fleet_balance_defs balance USING(content_snapshot_id)
 JOIN remote_support_state support USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 WHERE q.snapshot_id=NEW.snapshot_id AND (support.phase<>'cycling' OR profession.effect_stat<>'remote_repair_multiplier' OR profile.profession_id<>q.profession_id OR
 member.experience<rank.experience_required OR q.loyalty_at_payment<balance.loyalty_ready_min OR q.paid_tick>NEW.simulation_tick OR
 abs(q.restore_multiplier-(1+rank.effect_value*q.loyalty_at_payment/100.0))>0.000001 OR NOT EXISTS(SELECT 1 FROM crew_assignment_state assignment
 WHERE assignment.snapshot_id=q.snapshot_id AND assignment.profile_id=q.profile_id AND assignment.profession_id=q.profession_id AND assignment.ship_instance_id=support.ship_instance_id)))
 THEN RAISE(ABORT,'crew repair quote differs from paid engineering duty') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 JOIN frozen_ship_defs d ON d.content_snapshot_id=s.content_snapshot_id AND d.ship_id=s.ship_def_id
 JOIN frozen_fleet_balance_defs b USING(content_snapshot_id)
 WHERE f.snapshot_id=NEW.snapshot_id AND (s.policy_id<>'normal_owned' OR
 f.deploy_paid_credit<>f.generation*(b.deploy_fee_credit+CAST((d.base_ask_credit*b.deploy_hull_fee_bp+9999)/10000 AS INTEGER)) OR
 f.created_tick>NEW.simulation_tick OR f.finished_tick>NEW.simulation_tick OR f.retreat_remaining_s>b.retreat_charge_s OR f.return_remaining_s>b.return_s OR
 (f.phase='deployed' AND NOT EXISTS(SELECT 1 FROM crew_assignment_state assignment JOIN crew_member_state member USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 JOIN frozen_crew_profession_defs profession USING(content_snapshot_id,profession_id)
 WHERE assignment.snapshot_id=f.snapshot_id AND assignment.ship_instance_id=f.ship_instance_id AND profession.duty_kind='pilot' AND member.phase='hired' AND member.loyalty>=b.loyalty_ready_min AND member.unpaid_periods<b.arrears_period_limit)) OR
 (f.phase IN('deployed','retreating') AND (f.npc_instance_id IS NULL OR f.npc_instance_id<>f.ship_instance_id OR s.status<>'flying' OR s.hull<=0 OR
 s.ship_instance_id=(SELECT controlled_ship_id FROM player_state WHERE snapshot_id=f.snapshot_id))) OR
 (f.phase NOT IN('deployed','retreating') AND f.npc_instance_id IS NOT NULL) OR
 (f.phase='returning' AND (s.status<>'flying' OR f.return_station_id IS NULL OR f.return_remaining_s<=0 OR
 NOT EXISTS(SELECT 1 FROM frozen_station_defs station WHERE station.content_snapshot_id=f.content_snapshot_id AND station.station_id=f.return_station_id AND station.sector_id=f.sector_id))) OR
 (f.phase<>'returning' AND f.return_remaining_s<>0) OR (f.phase<>'retreating' AND f.retreat_remaining_s<>0) OR
 (f.phase='lost' AND (s.status<>'destroyed' OR s.hull<>0)) OR
 (f.phase IN('docked','lost') AND (f.finished_tick<f.created_tick OR f.end_reason='')) OR
 (f.order_kind='focus' AND (f.focus_target_id IS NULL OR NOT EXISTS(SELECT 1 FROM npc_state target WHERE target.snapshot_id=f.snapshot_id AND target.npc_instance_id=f.focus_target_id AND target.alive=1 AND target.sector_id=f.sector_id) OR
 EXISTS(SELECT 1 FROM fleet_deployment_state ally WHERE ally.snapshot_id=f.snapshot_id AND ally.npc_instance_id=f.focus_target_id))) OR
 (f.order_kind<>'focus' AND f.focus_target_id IS NOT NULL)))
 THEN RAISE(ABORT,'owned deployment payment lifecycle or command invalid') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM fleet_deployment_state f JOIN ship_state s USING(snapshot_id,world_id,content_snapshot_id,ship_instance_id)
 LEFT JOIN npc_state n ON n.snapshot_id=f.snapshot_id AND n.npc_instance_id=f.npc_instance_id
 LEFT JOIN frozen_fleet_hull_defs h ON h.content_snapshot_id=s.content_snapshot_id AND h.ship_id=s.ship_def_id
 LEFT JOIN spatial_state p ON p.snapshot_id=f.snapshot_id AND p.entity_kind='ship' AND p.entity_id=f.ship_instance_id
 LEFT JOIN spatial_state q ON q.snapshot_id=f.snapshot_id AND q.entity_kind='npc' AND q.entity_id=f.npc_instance_id
 WHERE f.snapshot_id=NEW.snapshot_id AND f.phase IN('deployed','retreating') AND
 (n.npc_instance_id IS NULL OR n.alive<>1 OR n.generation<>f.generation OR n.spawn_id IS NOT h.spawn_id OR
 s.owner_player_id<>(SELECT player_id FROM player_state WHERE snapshot_id=f.snapshot_id) OR
 n.sector_id<>f.sector_id OR s.sector_id<>f.sector_id OR p.site_id IS NOT f.site_id OR q.site_id IS NOT f.site_id OR
 abs(n.shield-s.shield)>0.00001 OR abs(n.armor-s.armor)>0.00001 OR abs(n.hull-s.hull)>0.00001 OR
 abs(n.pos_x-s.pos_x)>0.00001 OR abs(n.pos_y-s.pos_y)>0.00001 OR abs(n.pos_z-s.pos_z)>0.00001 OR
 abs(n.quat_x-s.quat_x)>0.00001 OR abs(n.quat_y-s.quat_y)>0.00001 OR abs(n.quat_z-s.quat_z)>0.00001 OR abs(n.quat_w-s.quat_w)>0.00001 OR
 abs(n.vel_x-s.vel_x)>0.00001 OR abs(n.vel_y-s.vel_y)>0.00001 OR abs(n.vel_z-s.vel_z)>0.00001))
 THEN RAISE(ABORT,'owned actor does not match its real hull') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM npc_state n JOIN frozen_fleet_hull_defs h USING(content_snapshot_id,spawn_id)
 WHERE n.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM fleet_deployment_state f WHERE f.snapshot_id=n.snapshot_id AND f.npc_instance_id=n.npc_instance_id AND f.phase IN('deployed','retreating')))
 THEN RAISE(ABORT,'unbound owned-fleet actor') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM auxiliary_bay_state a JOIN item_instance_state i USING(snapshot_id,world_id,content_snapshot_id,item_instance_id)
 LEFT JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id
 JOIN frozen_module_defs m ON m.content_snapshot_id=i.content_snapshot_id AND m.module_id=i.item_def_id
 WHERE a.snapshot_id=NEW.snapshot_id AND (d.module_id IS NULL OR a.stock_units>d.drone_count OR
 a.stock_units+a.lost_units<>d.drone_count+a.replenished_units OR a.deployed_units<>0 OR
 a.paid_credit_total<>a.replenished_units*d.credit_per_unit OR a.material_units_total<>a.replenished_units*d.material_per_unit OR
 abs(a.energy_paid_total-a.sorties*m.energy_eu)>0.00001 OR abs(a.heat_paid_total-a.sorties*m.heat_hu)>0.00001 OR a.consumable_paid_units<>a.sorties*d.consumable_per_sortie OR
 (d.role_kind='recon' AND a.repaired_hp<>0))) THEN RAISE(ABORT,'auxiliary stock cost or outstanding sortie invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM item_instance_state i JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=i.content_snapshot_id AND d.module_id=i.item_def_id
 WHERE i.snapshot_id=NEW.snapshot_id AND NOT EXISTS(SELECT 1 FROM auxiliary_bay_state a WHERE a.snapshot_id=i.snapshot_id AND a.item_instance_id=i.item_instance_id)) THEN RAISE(ABORT,'auxiliary bay stock is missing') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM equipment_state e JOIN container_state c ON c.snapshot_id=e.snapshot_id AND c.container_id=e.slot_container_id
 JOIN ship_state s ON s.snapshot_id=c.snapshot_id AND s.ship_instance_id=c.ship_instance_id
 JOIN frozen_auxiliary_drone_defs d ON d.content_snapshot_id=e.content_snapshot_id AND d.module_id=e.module_def_id
 LEFT JOIN frozen_ship_auxiliary_permissions p ON p.content_snapshot_id=s.content_snapshot_id AND p.ship_id=s.ship_def_id AND p.role_kind=d.role_kind
 WHERE e.snapshot_id=NEW.snapshot_id AND (p.ship_id IS NULL OR
 (SELECT count(*) FROM equipment_state other JOIN container_state oc ON oc.snapshot_id=other.snapshot_id AND oc.container_id=other.slot_container_id
 JOIN frozen_auxiliary_drone_defs od ON od.content_snapshot_id=other.content_snapshot_id AND od.module_id=other.module_def_id
 WHERE other.snapshot_id=e.snapshot_id AND oc.ship_instance_id=s.ship_instance_id AND od.role_kind=d.role_kind)>p.max_installed))
 THEN RAISE(ABORT,'auxiliary role exceeds hull permission') END;

 SELECT CASE WHEN EXISTS(SELECT 1 FROM auxiliary_intel_state i JOIN frozen_auxiliary_drone_defs d USING(content_snapshot_id,module_id)
 JOIN frozen_site_defs site USING(content_snapshot_id,site_id)
 WHERE i.snapshot_id=NEW.snapshot_id AND (d.role_kind<>'recon' OR site.sector_id<>i.sector_id OR i.observed_tick>NEW.simulation_tick)) THEN RAISE(ABORT,'auxiliary observation role location or time invalid') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM crew_receipt_state r JOIN crew_member_state c USING(snapshot_id,world_id,content_snapshot_id,profile_id)
 WHERE r.snapshot_id=NEW.snapshot_id AND (r.event_tick>NEW.simulation_tick OR r.revision>c.revision)) OR
 EXISTS(SELECT 1 FROM fleet_receipt_state r WHERE r.snapshot_id=NEW.snapshot_id AND r.event_tick>NEW.simulation_tick)
 THEN RAISE(ABORT,'crew/fleet receipt precedes its action') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM frozen_fleet_balance_defs b WHERE b.content_snapshot_id=NEW.content_snapshot_id AND
 ((SELECT count(*) FROM crew_receipt_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit OR
 (SELECT count(*) FROM fleet_receipt_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit OR
 (SELECT count(*) FROM auxiliary_intel_state WHERE snapshot_id=NEW.snapshot_id)>b.history_limit))
 THEN RAISE(ABORT,'fleet history exceeds retention limit') END;
END;
