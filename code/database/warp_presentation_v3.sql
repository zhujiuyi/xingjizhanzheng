-- Presentation-only v3. Published gameplay navigation v1/v2 remain unchanged.
PRAGMA application_id=1481262680;
PRAGMA user_version=3;
CREATE TABLE warp_presentation_meta (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 rule_version TEXT NOT NULL CHECK(rule_version='warp-presentation-v3')
);
INSERT INTO warp_presentation_meta VALUES (1,'warp-presentation-v3');
CREATE TABLE warp_visual_parameters (
 parameter_id TEXT PRIMARY KEY,
 value_real REAL NOT NULL CHECK(value_real>=0)
);
INSERT INTO warp_visual_parameters VALUES
('warp_fx_fade_in_s',0.35),
('warp_fx_fade_out_s',0.35),
('warp_fx_warmup_strength',0.18),
('warp_fx_blur_radius_px',36.0),
('warp_fx_blur_lod',3.2),
('warp_fx_fov_add_deg',4.0),
('warp_fx_mask_padding_ratio',1.03),
('warp_fx_mask_feather_px',6.0),
('warp_fx_center_clear_ratio',0.0),
('warp_fx_streak_count',30.0),
('warp_fx_streak_radius_ship_lengths',1.7),
('warp_fx_streak_length_ship_lengths',1.3),
('warp_fx_streak_extent_ship_lengths',12.0),
('warp_fx_streak_speed_ship_lengths_s',20.0),
('warp_fx_streak_width_ship_lengths',0.012),
('warp_fx_streak_alpha',0.35),
('warp_fx_warmup_speed_ratio',0.12),
('warp_fx_reference_height_px',900.0),
('warp_fx_departure_duration_s',0.45),
('warp_fx_departure_distance_ship_lengths',120.0),
('warp_fx_mask_resolution_scale',0.5);
