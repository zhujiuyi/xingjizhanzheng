-- Presentation/navigation definitions only. No combat, economy or save state.
PRAGMA foreign_keys=ON;
CREATE TABLE navigation_meta(singleton INTEGER PRIMARY KEY CHECK(singleton=1), version TEXT NOT NULL);
INSERT INTO navigation_meta VALUES(1,'navigation-v3');
CREATE TABLE radar_range_defs(range_id TEXT PRIMARY KEY, display_order INTEGER UNIQUE NOT NULL, radius_m REAL NOT NULL CHECK(radius_m>0));
INSERT INTO radar_range_defs VALUES('near',0,500),('local',1,2000),('sector',2,6000);
CREATE TABLE celestial_visual_defs(
 celestial_id TEXT PRIMARY KEY, sector_id TEXT UNIQUE NOT NULL, display_name TEXT NOT NULL,
 x_m REAL NOT NULL,y_m REAL NOT NULL,z_m REAL NOT NULL,render_radius_m REAL NOT NULL CHECK(render_radius_m>0),
 surface_color TEXT NOT NULL,cloud_color TEXT NOT NULL,visual_seed REAL NOT NULL,
 description TEXT NOT NULL
);
-- Compressed scenic placement: these are non-colliding navigation silhouettes,
-- not physical planetary size, flight landing locations or local sensor echoes.
INSERT INTO celestial_visual_defs VALUES
('celestial_anchor','sector_anchor','锚港一号',7800,1800,-6100,1900,'#516a70','#93a5a3',11,'远景天体 · 航向参考'),
('celestial_echo','sector_echo','回声带一号',-7000,2400,-6400,2100,'#5c5750','#b6b2a6',23,'远景天体 · 航向参考'),
('celestial_mirror','sector_mirror','镜湖一号',7100,-900,-7100,1800,'#3e5f76','#adbcc3',37,'远景天体 · 航向参考'),
('celestial_forge','sector_forge','熔脊一号',-7800,1100,-5100,1900,'#6b4934','#b5a591',41,'远景天体 · 航向参考'),
('celestial_iron','sector_iron','铁环一号',8200,1600,-5400,2300,'#4b5557','#b0af9c',53,'远景天体 · 航向参考'),
('celestial_helios','sector_helios','曜炉一号',-6500,-1000,-7200,2200,'#796c48','#d0c6a0',67,'远景天体 · 航向参考'),
('celestial_drift','sector_drift','游弋渡一号',7400,2000,-6600,1800,'#526865','#b6c4b7',71,'远景天体 · 航向参考'),
('celestial_mist','sector_mist','雾帆一号',-7100,2000,-6200,2100,'#525f6a','#acb9c3',83,'远景天体 · 航向参考'),
('celestial_rift','sector_rift','断弦一号',7600,-1100,-6100,1900,'#5c484a','#bba5a2',97,'远景天体 · 航向参考'),
('celestial_silent','sector_silent','静默渊一号',-7800,700,-6700,2000,'#3c4b55','#788f9c',109,'远景天体 · 航向参考');
