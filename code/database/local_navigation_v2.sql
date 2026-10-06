-- Fixed rules for v0.7 strategic sites. v1 remains byte-preserved for old worlds.
PRAGMA application_id = 1481526350;
PRAGMA user_version = 2;
CREATE TABLE local_navigation_meta (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    rule_version TEXT NOT NULL CHECK(rule_version='local-navigation-v2')
);
INSERT INTO local_navigation_meta VALUES (1,'local-navigation-v2');
CREATE TABLE navigation_parameters (
    parameter_id TEXT PRIMARY KEY,
    value_real REAL NOT NULL CHECK(value_real>0)
);
INSERT INTO navigation_parameters VALUES
('warmup_s',2.0),
('alignment_tolerance_rad',0.08),
('warp_speed_mps',26927616726.0), -- 0.18 AU/s
('min_warp_distance_m',150000.0),
('min_warp_travel_s',3.0),
('approach_speed_fraction',0.8),
('orbit_speed_fraction',0.5),
('steering_response_s',0.25),
('orbit_radial_response_s',2.0),
('arrival_tolerance_m',8.0),
('arrival_speed_mps',1.0),
('collision_margin_m',8.0),
('warp_fx_fade_in_s',0.35),
('warp_fx_fade_out_s',0.35),
('warp_fx_warmup_strength',0.18),
('warp_fx_blur_radius_px',8.0),
('warp_fx_blur_lod',1.25),
('warp_fx_fov_add_deg',4.0),
('warp_fx_mask_padding_ratio',1.10),
('warp_fx_mask_feather_px',12.0),
('warp_fx_center_clear_ratio',0.12),
('warp_fx_streak_count',72.0),
('warp_fx_streak_radius_ship_lengths',1.6),
('warp_fx_streak_length_ship_lengths',2.1),
('warp_fx_streak_extent_ship_lengths',12.0),
('warp_fx_streak_speed_ship_lengths_s',20.0),
('warp_fx_streak_width_ship_lengths',0.003),
('warp_fx_streak_alpha',0.22),
('warp_fx_warmup_speed_ratio',0.12);
CREATE TABLE navigation_target_rules (
    target_kind TEXT PRIMARY KEY,
    warp_arrival_m REAL CHECK(warp_arrival_m IS NULL OR warp_arrival_m>0),
    approach_arrival_m REAL NOT NULL CHECK(approach_arrival_m>0),
    orbit_radius_m REAL NOT NULL CHECK(orbit_radius_m>approach_arrival_m)
);
INSERT INTO navigation_target_rules VALUES
('station',500.0,500.0,700.0),
('gate',280.0,100.0,450.0),
('resource',180.0,160.0,350.0),
('signal',160.0,80.0,250.0),
('marker',160.0,80.0,250.0),
('npc',NULL,400.0,500.0),
('wreck',NULL,80.0,250.0);
