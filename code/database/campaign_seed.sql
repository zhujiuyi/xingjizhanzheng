INSERT INTO campaign_balance_defs VALUES(1,1800.0,11000,5000,20);
INSERT INTO construction_project_defs VALUES
 ('project_frontier_01','晨岬航路重建','sector_frontier_01','station_frontier_01','unlock_open_routes',2,'跨站集货修复边疆服务；主权失守保留投入，收复后继续。'),
 ('project_frontier_02','浮屿补给枢纽','sector_frontier_02','station_frontier_02','unlock_open_routes',2,'将采集与加工产物投入补给网络；完整或多份部分调查均可贡献。'),
 ('project_frontier_03','寒浦远域工坊','sector_frontier_03','station_frontier_03','unlock_open_routes',2,'建设远征维修和制造节点，保留每一批交付及已完成阶段。');
INSERT INTO construction_stage_defs VALUES
 ('project_frontier_01',1,'重建制造工位',60.0,1000,'manufacture_fee',9000),('project_frontier_01',2,'修复维护坞',120.0,2000,'repair_fee',9000),('project_frontier_01',3,'恢复补给网络',180.0,4000,'stock_refresh',11000),
 ('project_frontier_02',1,'重建制造工位',60.0,1000,'manufacture_fee',9000),('project_frontier_02',2,'修复维护坞',120.0,2000,'repair_fee',9000),('project_frontier_02',3,'恢复补给网络',180.0,4000,'stock_refresh',11000),
 ('project_frontier_03',1,'重建制造工位',60.0,1000,'manufacture_fee',9000),('project_frontier_03',2,'修复维护坞',120.0,2000,'repair_fee',9000),('project_frontier_03',3,'恢复补给网络',180.0,4000,'stock_refresh',11000);
INSERT INTO construction_input_defs VALUES
 ('project_frontier_01',1,'ore_ferrosilicate','station_echo_depot',120),('project_frontier_01',1,'material_structural_stock','station_frontier_01',40),
 ('project_frontier_01',2,'ore_conductive_crystal','station_mirror_hub',30),('project_frontier_01',2,'material_structural_stock','station_frontier_01',60),
 ('project_frontier_01',3,'ore_ferrosilicate','station_echo_depot',180),('project_frontier_01',3,'material_structural_stock','station_frontier_01',100),
 ('project_frontier_02',1,'ore_ferrosilicate','station_echo_depot',120),('project_frontier_02',1,'material_structural_stock','station_frontier_02',40),
 ('project_frontier_02',2,'ore_conductive_crystal','station_mirror_hub',30),('project_frontier_02',2,'material_structural_stock','station_frontier_02',60),
 ('project_frontier_02',3,'ore_ferrosilicate','station_echo_depot',180),('project_frontier_02',3,'material_structural_stock','station_frontier_02',100),
 ('project_frontier_03',1,'ore_ferrosilicate','station_echo_depot',120),('project_frontier_03',1,'material_structural_stock','station_frontier_03',40),
 ('project_frontier_03',2,'ore_conductive_crystal','station_mirror_hub',30),('project_frontier_03',2,'material_structural_stock','station_frontier_03',60),
 ('project_frontier_03',3,'ore_ferrosilicate','station_echo_depot',180),('project_frontier_03',3,'material_structural_stock','station_frontier_03',100);
INSERT INTO expedition_route_defs VALUES
 ('route_relief','边疆救援线','station_mirror_hub','unlock_open_routes',800,900.0,0,'分段调查晨岬、浮屿、寒浦；每段结算后可结束，救援协调奖励更高。'),
 ('route_supply','资源补给线','station_mirror_hub','unlock_open_routes',1100,900.0,1,'矿物与运输路线侧重工程供给；已结算段落不因后续失败清空。'),
 ('route_archive','异常档案线','station_mirror_hub','unlock_open_routes',1400,900.0,2,'遗迹取证侧重可积累研究；保留部分成果和随时撤回的选择。');
INSERT INTO expedition_option_defs VALUES
 ('route_relief',1,'relief','exp_theme_frontier_01_rescue',600,2),('route_relief',1,'archive','exp_theme_frontier_01_relic',400,2),
 ('route_relief',2,'mineral','exp_theme_frontier_02_mineral',800,2),('route_relief',2,'relief','exp_theme_frontier_02_rescue',1200,3),
 ('route_relief',3,'mineral','exp_theme_frontier_03_mineral',1600,4),('route_relief',3,'archive','exp_theme_frontier_03_relic',2000,4),
 ('route_supply',1,'relief','exp_theme_frontier_01_rescue',500,1),('route_supply',1,'archive','exp_theme_frontier_01_relic',600,2),
 ('route_supply',2,'mineral','exp_theme_frontier_02_mineral',1400,2),('route_supply',2,'relief','exp_theme_frontier_02_rescue',1000,2),
 ('route_supply',3,'mineral','exp_theme_frontier_03_mineral',2600,3),('route_supply',3,'archive','exp_theme_frontier_03_relic',2000,4),
 ('route_archive',1,'relief','exp_theme_frontier_01_rescue',400,2),('route_archive',1,'archive','exp_theme_frontier_01_relic',500,4),
 ('route_archive',2,'mineral','exp_theme_frontier_02_mineral',900,3),('route_archive',2,'relief','exp_theme_frontier_02_rescue',900,3),
 ('route_archive',3,'mineral','exp_theme_frontier_03_mineral',1800,5),('route_archive',3,'archive','exp_theme_frontier_03_relic',2200,8);
INSERT INTO campaign_event_defs VALUES
 ('exp_theme_frontier_01_rescue','project_frontier_01',2,1),('exp_theme_frontier_01_relic','project_frontier_01',2,1),
 ('exp_theme_frontier_02_mineral','project_frontier_02',2,1),('exp_theme_frontier_02_rescue','project_frontier_02',2,1),
 ('exp_theme_frontier_03_mineral','project_frontier_03',2,1),('exp_theme_frontier_03_relic','project_frontier_03',2,1);
UPDATE exploration_event_defs SET cooldown_s=120.0 WHERE event_id LIKE 'exp_theme_%';
UPDATE catalog_meta SET schema_version=20,content_version='v0.21-campaign',ruleset_version='singleplayer_campaign_v1',source_document='doc/64-远征建设与主题行动.md';
