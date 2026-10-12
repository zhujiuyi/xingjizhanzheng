-- Values authored here are the single balance authority for this batch.
UPDATE catalog_meta SET content_version='v0.22-scenarios',ruleset_version='singleplayer_scenarios_v1',schema_version=21,source_document='doc/65-配装挑战航路封锁与行为记录.md',content_hash='pending' WHERE singleton=1;
INSERT INTO tactical_award_defs VALUES
 ('award_precision','远距射手','在受限舰型与预算内完成实际远距命中。'),
 ('award_escort','护航卫士','保护实体运输舰抵达终点。'),
 ('award_support','损管专家','完成有效远程维修并护送伤舰脱离。'),
 ('award_blockade_echo','静默穿行者','完整送达回声封锁航路的任务货物。'),
 ('award_blockade_mirror','破链先锋','完整送达镜湖封锁航路的任务货物。'),
 ('award_blockade_drift','远航引路人','完整送达漂流封锁航路的任务货物。');

CREATE TEMP TABLE scenario_places(id TEXT,sector TEXT,station TEXT,reference_site TEXT,title TEXT,offset_au REAL);
INSERT INTO scenario_places VALUES
 ('trial_precision','sector_anchor','station_anchor_port','site_anchor_station','锚港远距校准场',0.11),
 ('trial_escort','sector_echo','station_echo_depot','site_echo_station','回声护航演练区',0.14),
 ('trial_support','sector_mirror','station_mirror_hub','site_mirror_station','镜湖损管演练区',0.17),
 ('blockade_echo','sector_echo','station_echo_depot','site_echo_station','回声灰带封锁线',0.23),
 ('blockade_mirror','sector_mirror','station_mirror_hub','site_mirror_station','镜湖失序封锁线',0.27),
 ('blockade_drift','sector_drift','station_drift_hub','site_drift_station','漂流外缘封锁线',0.31);
INSERT INTO site_defs
 SELECT p.id||'_site',p.sector,p.title,'encounter',s.x_m+p.offset_au*149597870700.0,s.y_m+p.offset_au*1495978707.0,s.z_m-p.offset_au*74798935350.0,0.0,0.0,0.0,s.local_radius_m
 FROM scenario_places p JOIN site_defs s ON s.site_id=p.reference_site;

CREATE TEMP TABLE scenario_anchors(id TEXT,owner TEXT,kind TEXT,x REAL,y REAL,z REAL,r REAL,safe REAL);
INSERT INTO scenario_anchors VALUES
 ('trial_precision_entry','trial_precision','signal',0,0,0,600,180),('trial_precision_exit','trial_precision','signal',0,0,0,600,180),('trial_precision_target_anchor','trial_precision','npc_spawn',0,0,-4500,100,80),
 ('trial_escort_entry','trial_escort','signal',0,0,0,600,180),('trial_escort_exit','trial_escort','signal',0,0,-6000,600,180),('trial_escort_convoy_anchor','trial_escort','npc_spawn',0,0,-300,100,80),('trial_escort_raider_0_anchor','trial_escort','npc_spawn',1200,0,-1800,100,80),('trial_escort_raider_1_anchor','trial_escort','npc_spawn',-1000,0,-3900,100,80),
 ('trial_support_entry','trial_support','signal',0,0,0,600,180),('trial_support_exit','trial_support','signal',0,0,-3000,600,180),('trial_support_patient_anchor','trial_support','npc_spawn',0,0,-300,100,80);
INSERT INTO scenario_anchors
 SELECT id||'_entry',id,'signal',0,0,-6000,600,180 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_exit',id,'signal',0,0,6000,600,180 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_survey_0',id,'signal',-2800,100,-3600,500,100 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_survey_1',id,'signal',2800,-100,-3000,500,100 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_relay_0_anchor',id,'npc_spawn',-800,0,0,100,80 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_relay_1_anchor',id,'npc_spawn',800,0,0,100,80 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_raider_0_anchor',id,'npc_spawn',1000,0,-600,100,80 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_anchors
 SELECT id||'_raider_1_anchor',id,'npc_spawn',-1200,0,1000,100,80 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO anchor_defs
 SELECT a.id,p.sector,a.kind,a.x,a.y,a.z,0.0,a.r,0.0 FROM scenario_anchors a JOIN scenario_places p ON p.id=a.owner;
INSERT INTO anchor_site_defs SELECT id,owner||'_site' FROM scenario_anchors;

INSERT INTO trial_defs VALUES
 ('trial_precision','远距火控挑战','precision','station_anchor_port','trial_precision_entry','trial_precision_exit','unlock_open_routes','award_precision',45000,300,180,600,1000,1500,180,0,180,'在1—1.5公里窗口造成180点实际归属伤害。'),
 ('trial_escort','有限预算护航','escort','station_echo_depot','trial_escort_entry','trial_escort_exit','unlock_open_routes','award_escort',120000,600,240,600,0,8000,1,0,240,'运输舰实际抵达出口且存活；不要求消灭全部敌人。'),
 ('trial_support','移动损管挑战','support','station_mirror_hub','trial_support_entry','trial_support_exit','unlock_open_routes','award_support',350000,800,180,600,0,8000,120,3,240,'伤舰持续受环境侵蚀，实际维修至少120耐久并护送抵达出口。');
INSERT INTO trial_hull_defs VALUES
 ('trial_precision','frigate_kestrel'),('trial_precision','frigate_lantern'),
 ('trial_escort','frigate_kestrel'),('trial_escort','destroyer_raptor'),('trial_escort','transport_caravan'),
 ('trial_support','support_weaver'),('trial_support','support_council_choir');

CREATE TEMP TABLE scenario_npcs(spawn TEXT,owner TEXT,role TEXT,template TEXT,anchor TEXT,behavior TEXT,model TEXT,speed REAL,armor_bp INTEGER);
INSERT INTO scenario_npcs VALUES
 ('trial_precision_target','trial_precision','target','npc_guardian_heavy_l6','trial_precision_target_anchor','exp_transport_behavior',NULL,0,10000),
 ('trial_escort_convoy','trial_escort','escort','npc_raider_medium_l3','trial_escort_convoy_anchor','exp_transport_behavior','transport_caravan',60,10000),
 ('trial_escort_raider_0','trial_escort','raider','npc_scout_light_l1','trial_escort_raider_0_anchor','tac_interceptor_behavior',NULL,0,10000),
 ('trial_escort_raider_1','trial_escort','raider','npc_scout_light_l1','trial_escort_raider_1_anchor','tac_interceptor_behavior',NULL,0,10000),
 ('trial_support_patient','trial_support','patient','npc_raider_medium_l3','trial_support_patient_anchor','exp_transport_behavior','support_weaver',80,4000);
INSERT INTO scenario_npcs
 SELECT id||'_relay_0',id,'relay','npc_raider_medium_l3',id||'_relay_0_anchor','exp_transport_behavior',NULL,0,10000 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_npcs
 SELECT id||'_relay_1',id,'relay','npc_raider_medium_l3',id||'_relay_1_anchor','exp_transport_behavior',NULL,0,10000 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_npcs
 SELECT id||'_raider_0',id,'raider','npc_scout_light_l1',id||'_raider_0_anchor','tac_interceptor_behavior',NULL,0,10000 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO scenario_npcs
 SELECT id||'_raider_1',id,'raider','npc_raider_medium_l3',id||'_raider_1_anchor','tac_siege_behavior',NULL,0,10000 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO npc_defs SELECT a.spawn||'_npc',n.archetype_id,min(max(n.level,z.npc_level_min),z.npc_level_max),r.risk_zone_id FROM scenario_npcs a JOIN npc_defs n ON n.npc_id=a.template JOIN scenario_places p ON p.id=a.owner JOIN sector_defs r ON r.sector_id=p.sector JOIN risk_zone_defs z ON z.risk_zone_id=r.risk_zone_id;
INSERT INTO npc_spawn_defs
 SELECT a.spawn,a.spawn||'_npc',p.sector,a.anchor,(SELECT b.behavior_id FROM npc_behavior_defs b JOIN npc_defs n ON n.archetype_id=b.archetype_id WHERE n.npc_id=a.template),'mission_scoped','unlock_open_routes',NULL,0,0 FROM scenario_npcs a JOIN scenario_places p ON p.id=a.owner;
INSERT INTO anchor_defs SELECT a.spawn||'_patrol',p.sector,'patrol',d.x_m,d.y_m,d.z_m,0.0,100.0,0.0 FROM scenario_npcs a JOIN scenario_places p ON p.id=a.owner JOIN anchor_defs d ON d.anchor_id=a.anchor;
INSERT INTO anchor_site_defs SELECT spawn||'_patrol',owner||'_site' FROM scenario_npcs;
INSERT INTO npc_patrol_points SELECT spawn,0,spawn||'_patrol' FROM scenario_npcs;
INSERT INTO trial_actor_defs SELECT spawn,owner,role,model,speed,armor_bp FROM scenario_npcs WHERE owner LIKE 'trial_%';
INSERT INTO blockade_defs
 SELECT id,title,station,id||'_entry',id||'_exit','unlock_open_routes','award_'||id,500,360,12,10000,60,600,2400,2000,80,8,2,120,90,700,4,300,
 '调查两个侧路节点获得通行窗口，或拆除两个中继解除局部封锁；按实际送达数量结算。'
 FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO blockade_node_defs SELECT id,0,'survey',id||'_survey_0' FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO blockade_node_defs SELECT id,1,'survey',id||'_survey_1' FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO blockade_node_defs SELECT id,2,'relay',id||'_relay_0_anchor' FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO blockade_node_defs SELECT id,3,'relay',id||'_relay_1_anchor' FROM scenario_places WHERE id LIKE 'blockade_%';
INSERT INTO blockade_actor_defs
 SELECT spawn,owner,role,CASE WHEN spawn LIKE '%relay_0' THEN 2 WHEN spawn LIKE '%relay_1' THEN 3 ELSE NULL END FROM scenario_npcs WHERE owner LIKE 'blockade_%';
INSERT INTO telemetry_policy_defs VALUES(1,128,5.0,'仅本地游戏行为；呈现时间与世界模拟时间分开，保留累计值。');
DROP TABLE scenario_npcs;DROP TABLE scenario_anchors;DROP TABLE scenario_places;
