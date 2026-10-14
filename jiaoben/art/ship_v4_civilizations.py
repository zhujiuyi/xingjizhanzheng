"""Nine original civilization hull recipes for ship-v4.

Coordinates are fractions of the retained W/H/L envelope, forward is -Z.
Recipes contain no thrusters or armament: the main builder supplies the real
engine anchors and weapon mounts. Each silhouette is authored independently.
"""


def council_sentinel(d):
    """Long paired swept shells, a recessed lower keel and an open throat."""
    d.curved('Sentinel_lower_pressure_keel', [(-.47,.035,.07,-.13,0),(-.30,.18,.16,-.15,0),(.04,.25,.19,-.13,0),(.29,.24,.18,-.08,0),(.40,.30,.17,-.02,0)], 'secondary')
    for side in (-1, 1):
        d.curved('Sentinel_swept_mantle', [(-.37,.035,.05,.01,side*.16),(-.22,.24,.24,.04,side*.24),(.02,.30,.27,.06,side*.25),(.24,.24,.20,.03,side*.22),(.36,.15,.14,0,side*.18)])
        d.wing('Sentinel_open_shoulder', [(side*.13,-.28),(side*.43,-.06),(side*.36,.25),(side*.18,.32),(side*.22,.05)], -.09,.045,'paint')
        d.beam('Sentinel_keel_saddle',(side*.10,-.15,-.10),(side*.24,-.02,-.04),.012,'trim')
        d.beam('Sentinel_rear_saddle',(side*.09,-.11,.23),(side*.19,0,.35),.012,'secondary')
        d.curved('Sentinel_copper_collar',[(-.12,.05,.045,.16,side*.26),(.02,.07,.055,.18,side*.27),(.16,.045,.04,.12,side*.25)],'trim')
        d.curved('Sentinel_exposed_mechanical_waist',[(-.16,.245,.035,.035,side*.255),(.015,.312,.044,.045,side*.25),(.17,.235,.035,.025,side*.235)],'dark')
        d.block('Sentinel_access_hood',(.075,.038,.085),(side*.29,.19,.075),'secondary')
        d.windows(side*.375,.06,.04,count=4,spacing=.024,side=True)
    d.curved('Sentinel_command_shell',[(-.09,.07,.05,.16,0),(.02,.19,.10,.19,0),(.17,.15,.09,.16,0),(.24,.06,.04,.10,0)],'hull')
    d.curved('Sentinel_recessed_bridge_glazing',[(-.075,.055,.025,.188,0),(.015,.14,.035,.225,0),(.085,.11,.025,.218,0)],'glass')
    d.fin('Sentinel_aft_sensor_blade',[(.10,.17),(.32,.28),(.28,.36),(.04,.35)],0,.025,'paint')
    d.radiator(0,-.22,.18,width=.13,length=.16,rows=4)
    d.beam('Sentinel_engine_transom',(-.23,0,.355),(.23,0,.355),.015,'dark')


def council_aegis(d):
    """One thick oval shield shell above a narrow suspended keel; no cockpit crown."""
    d.curved('Aegis_single_oval_shield_hull',[(-.46,.06,.13,-.02,0),(-.34,.43,.36,0,0),(-.17,.79,.51,.015,0),(.035,.89,.55,.015,0),(.22,.70,.43,0,0),(.37,.42,.25,-.015,0)])
    d.curved('Aegis_lower_suspended_keel',[(-.41,.035,.06,-.18,0),(-.24,.11,.17,-.27,0),(.05,.14,.20,-.28,0),(.25,.12,.16,-.22,0),(.38,.27,.12,-.06,0)],'dark')
    d.curved('Aegis_flush_upper_armor_tier',[(-.24,.17,.035,.245,0),(-.10,.46,.045,.28,0),(.09,.54,.045,.30,0),(.21,.27,.035,.23,0)],'secondary')
    d.curved('Aegis_recessed_equatorial_belt',[(-.29,.48,.035,-.005,0),(-.13,.82,.045,.005,0),(.045,.905,.045,.005,0),(.20,.73,.035,-.005,0)],'dark')
    for side in (-1, 1):
        d.curved('Aegis_thin_copper_shield_arc',[(-.25,.025,.07,.015,side*.27),(-.095,.033,.08,.02,side*.42),(.08,.035,.08,.015,side*.445),(.22,.025,.065,-.01,side*.34)],'trim')
        d.wing('Aegis_lower_shield_skirt',[(side*.27,-.22),(side*.43,-.10),(side*.46,.08),(side*.34,.23),(side*.27,.20),(side*.36,.045)],-.105,.032,'paint')
        d.beam('Aegis_keel_structural_saddle',(side*.10,-.16,-.16),(side*.055,-.25,-.10),.012,'secondary')
        d.windows(side*.445,.045,.055,count=4,spacing=.023,side=True)
    d.ring('Aegis_flush_reactor_service_seal',(0,.292,.06),.105,.115,.010,'trim',32,axis='y')
    d.block('Aegis_reactor_recess',(.11,.018,.12),(0,.292,.06),'ceramic')
    d.loft('Aegis_small_forward_bridge_slit',[(-.15,.09,.011,.263,0),(-.095,.14,.014,.285,0),(-.055,.09,.011,.285,0)],'glass',.10)
    d.radiator(0,-.37,.115,width=.12,length=.17,rows=4)
    d.beam('Aegis_stern_load_bridge',(-.24,0,.35),(.24,0,.35),.019,'secondary')


def council_choir(d):
    """An open tuning fork surrounding a large transverse communications halo."""
    for side in (-1, 1):
        d.curved('Choir_long_fork_shell',[(-.46,.025,.05,-.02,side*.25),(-.31,.15,.16,.01,side*.27),(-.03,.19,.20,.02,side*.28),(.25,.16,.18,0,side*.25),(.39,.16,.14,0,side*.18)])
        d.curved('Choir_outer_pearl_ridge',[(-.25,.025,.03,.10,side*.33),(.01,.04,.05,.13,side*.35),(.23,.025,.03,.09,side*.29)],'trim')
        d.curved('Choir_recessed_fork_waist',[(-.22,.16,.03,0,side*.28),(.015,.197,.035,.012,side*.28),(.20,.165,.03,0,side*.26)],'dark')
        d.block('Choir_receiver_service_cover',(.055,.03,.075),(side*.29,.125,.12),'secondary')
        d.beam('Choir_halo_mount',(side*.25,.01,.02),(side*.20,-.15,.05),.012,'secondary')
        d.wing('Choir_forward_receiver',[(side*.24,-.37),(side*.43,-.26),(side*.39,-.11),(side*.28,-.07)],.04,.035,'paint')
        d.ring('Choir_receiver_iris',(side*.26,.10,-.22),.075,.07,.014,'dark',24,axis='y')
        d.windows(side*.37,.02,.14,count=4,spacing=.026,side=True)
    d.ring('Choir_transverse_halo',(0,.07,.015),.275,.30,.035,'trim',56)
    d.ring('Choir_halo_inner_liner',(0,.07,.022),.235,.255,.018,'dark',48)
    d.curved('Choir_low_pressure_bridge',[(-.20,.055,.055,-.21,0),(-.02,.19,.10,-.22,0),(.23,.23,.14,-.17,0),(.39,.31,.16,-.02,0)],'secondary')
    d.curved('Choir_control_pod',[(.08,.07,.05,-.15,0),(.19,.15,.10,-.12,0),(.29,.11,.07,-.09,0)],'hull')
    d.curved('Choir_control_glass',[(.10,.05,.022,-.115,0),(.18,.10,.03,-.063,0),(.25,.055,.02,-.06,0)],'glass')
    d.beam('Choir_halo_spine',(0,.33,.015),(0,.13,.24),.010,'paint')
    d.beam('Choir_engine_transom',(-.24,0,.36),(.24,0,.36),.015,'secondary')
    d.radiator(0,-.26,.16,width=.12,length=.13,rows=4)


def forge_hammer(d):
    """Tall forged cleaver: vertical forward wedge and a staggered side casemate."""
    d.loft('Hammer_vertical_pressure_wedge',[(-.48,.035,.16,0,0),(-.34,.16,.58,.01,0),(-.05,.22,.69,.015,0),(.22,.24,.44,-.01,0),(.39,.31,.22,0,0)],'hull',.13)
    d.fin('Hammer_dorsal_cutting_plate',[(.10,-.36),(.34,-.30),(.43,.035),(.27,.23),(.08,.28)],0,.045,'paint')
    d.fin('Hammer_ventral_armored_skeg',[(-.12,-.34),(-.35,-.15),(-.39,.03),(-.19,.23),(-.07,.25)],0,.055,'dark')
    d.loft('Hammer_port_casemate',[(-.25,.05,.10,-.06,-.20),(-.10,.24,.25,-.08,-.23),(.17,.22,.25,-.08,-.23),(.31,.10,.15,-.02,-.20)],'secondary',.12)
    d.loft('Hammer_starboard_service_cowl',[(-.12,.05,.08,-.07,.16),(.05,.15,.22,-.08,.18),(.26,.14,.18,-.02,.19),(.36,.10,.13,0,.18)],'hull',.16)
    d.fin('Hammer_port_recessed_service_belt',[(-.12,-.18),(-.055,-.16),(-.045,.16),(-.11,.20)],-.355,.012,'dark')
    d.wing('Hammer_overlapping_dorsal_shield',[(-.09,-.20),(.08,-.17),(.085,.02),(-.08,.08)],.345,.035,'secondary')
    d.loft('Hammer_offset_command_brow',[(-.03,.07,.08,.22,-.09),(.08,.13,.13,.24,-.10),(.17,.07,.08,.20,-.08)],'trim',.15)
    d.loft('Hammer_bridge_glass',[(-.025,.05,.024,.255,-.09),(.065,.095,.036,.295,-.10),(.11,.05,.02,.26,-.09)],'glass',.12)
    for side in (-1, 1):
        d.beam('Hammer_aft_power_buttress',(side*.10,-.04,.19),(side*.18,0,.39),.018,'dark')
        d.fin('Hammer_stern_armored_cheek',[(-.12,.18),(.12,.23),(.13,.37),(-.05,.39)],side*.20,.045,'secondary')
        d.beam('Hammer_fore_wedge_rib',(side*.09,.10,-.31),(side*.12,.20,-.08),.008,'trim')
    d.radiator(-.24,-.20,.10,width=.17,length=.16,rows=4)
    d.windows(-.17,.24,.06,count=3,spacing=.025,side=True)
    d.block('Hammer_rear_maintenance_hatch',(.11,.045,.09),(.16,.13,.27),'ceramic')
    d.beam('Hammer_transverse_stern',(-.23,0,.35),(.23,0,.35),.018,'secondary')


def forge_citadel(d):
    """A dense left-shifted tall wedge with one short, low cantilevered mission pod."""
    d.loft('Citadel_monolithic_offset_casemate',[(-.46,.10,.19,-.05,-.12),(-.31,.50,.50,-.005,-.11),(-.10,.65,.65,.005,-.08),(.17,.58,.57,-.015,-.06),(.34,.35,.26,-.02,-.02)],'hull',.10)
    d.loft('Citadel_ventral_reactor_keel',[(-.30,.12,.08,-.24,-.09),(-.08,.24,.13,-.34,-.06),(.18,.22,.12,-.285,-.035),(.37,.34,.18,-.045,0)],'dark',.12)
    d.loft('Citadel_overlapping_upper_armor',[(-.23,.30,.045,.25,-.115),(-.085,.45,.06,.33,-.09),(.055,.40,.055,.30,-.07),(.20,.22,.04,.225,-.045)],'secondary',.12)
    d.loft('Citadel_short_starboard_mission_pod',[(-.055,.13,.15,-.13,.31),(.025,.25,.32,-.13,.335),(.17,.23,.32,-.125,.34),(.27,.13,.16,-.10,.30)],'secondary',.14)
    d.wing('Citadel_mission_pod_protective_shelf',[(.16,-.04),(.425,-.025),(.47,.08),(.44,.22),(.21,.25)],.045,.04,'paint')
    d.beam('Citadel_forward_cantilever_root',(.12,-.07,.025),(.335,-.13,.025),.022,'dark')
    d.beam('Citadel_rear_cantilever_root',(.12,-.055,.19),(.33,-.12,.19),.024,'trim')
    d.truss((.16,-.23,.015),(.345,-.23,.19),.020,3)
    d.fin('Citadel_port_inset_service_belt',[(-.055,-.23),(.015,-.20),(.025,.12),(-.035,.23)],-.415,.012,'dark')
    d.fin('Citadel_port_command_slit',[(.12,-.055),(.15,-.035),(.14,.075),(.105,.10)],-.405,.006,'glass')
    d.fin('Citadel_lower_armor_cheek',[(-.14,-.28),(-.035,-.21),(-.07,.17),(-.19,.20)],-.37,.045,'secondary')
    d.wing('Citadel_top_warning_stripe',[(-.27,-.18),(-.20,-.16),(-.14,.06),(-.20,.08)],.345,.012,'paint')
    d.block('Citadel_upper_maintenance_recess',(.10,.025,.10),(-.06,.34,.02),'ceramic')
    d.windows(.46,-.06,.10,count=3,spacing=.025,side=True)
    d.radiator(-.22,-.28,.12,width=.17,length=.17,rows=4)
    d.loft('Citadel_buried_stern_power_base',[(.25,.36,.23,-.015,0),(.38,.43,.20,0,0)],'secondary',.13)


def forge_ironwall(d):
    """A broad hammerhead bow, narrow exposed waist and a tall rear command nave."""
    d.loft('Ironwall_deep_central_keel',[(-.47,.055,.13,-.10,0),(-.30,.28,.31,-.10,0),(-.04,.32,.34,-.11,0),(.25,.34,.31,-.05,0),(.40,.39,.23,0,0)],'secondary',.11)
    d.loft('Ironwall_hammerhead_bow',[(-.39,.30,.19,.02,0),(-.28,.90,.29,.035,0),(-.11,.84,.27,.035,0),(-.045,.45,.18,-.005,0)],'hull',.12)
    for side in (-1, 1):
        d.loft('Ironwall_forward_shoulder_tower',[(-.30,.09,.15,.14,side*.33),(-.18,.20,.37,.15,side*.34),(-.055,.16,.31,.13,side*.33),(.015,.07,.13,.035,side*.29)],'hull',.13)
        d.fin('Ironwall_tower_coat',[(.02,-.28),(.32,-.21),(.27,-.07),(.045,-.025)],side*.38,.022,'paint')
        d.fin('Ironwall_tower_armored_waist',[(.065,-.265),(.115,-.24),(.10,-.08),(.055,-.055)],side*.445,.012,'dark')
        d.truss((side*.17,-.10,-.01),(side*.31,-.03,.23),.025,3)
        d.loft('Ironwall_aft_reactor_wing',[(.17,.12,.15,-.03,side*.25),(.27,.25,.29,-.015,side*.27),(.38,.16,.18,0,side*.19)],'secondary',.18)
        d.windows(side*.25,.19,.22,count=3,spacing=.028,side=True)
    d.loft('Ironwall_rear_command_nave',[(.03,.11,.13,.14,0),(.14,.19,.29,.22,0),(.27,.15,.25,.22,0),(.34,.08,.10,.12,0)],'hull',.12)
    d.fin('Ironwall_nave_crest',[(.22,.08),(.43,.16),(.39,.29),(.12,.34)],0,.065,'trim')
    d.loft('Ironwall_observation_slit',[(.09,.07,.02,.305,0),(.17,.13,.025,.375,0),(.23,.09,.02,.35,0)],'glass',.10)
    d.radiator(0,-.29,.12,width=.18,length=.21,rows=4)
    d.beam('Ironwall_stern_power_bridge',(-.30,0,.355),(.30,0,.355),.024,'dark')


def roaming_spear(d):
    """Off-center long spear spine and an open starboard sail outrigger."""
    d.curved('Spear_offset_long_pressure_hull',[(-.48,.025,.04,-.02,-.13),(-.32,.12,.13,-.01,-.14),(-.12,.23,.23,0,-.16),(.17,.22,.24,-.015,-.15),(.35,.16,.16,0,-.12)],'hull')
    d.curved('Spear_starboard_aft_capsule',[(.03,.06,.075,-.03,.29),(.16,.18,.18,0,.30),(.30,.16,.18,.01,.28),(.37,.08,.11,0,.23)],'secondary')
    d.truss((.29,0,-.32),(.31,0,.29),.025,4)
    d.truss((-.10,-.07,-.14),(.29,-.045,.03),.020,3)
    d.beam('Spear_outrigger_lower_chord',(.29,-.09,-.27),(.30,-.09,.24),.008,'dark')
    d.fin('Spear_tall_trimmed_sail',[(.02,-.27),(.34,-.16),(.31,.09),(.07,.23),(-.015,.08)],.375,.018,'paint')
    d.fin('Spear_sail_inner_laminate',[(.07,-.20),(.27,-.12),(.24,.055),(.085,.14)],.386,.007,'ceramic')
    d.fin('Spear_port_ventral_return',[(-.05,-.03),(-.25,.06),(-.18,.24),(-.03,.29)],-.28,.027,'trim')
    d.curved('Spear_offset_command_brow',[(-.18,.05,.04,.12,-.15),(-.05,.13,.09,.16,-.17),(.06,.10,.075,.13,-.16)],'paint')
    d.curved('Spear_exposed_spine_service_channel',[(-.17,.20,.036,-.025,-.16),(.02,.235,.04,-.02,-.16),(.19,.205,.03,-.025,-.15)],'dark')
    d.block('Spear_offaxis_service_lock',(.06,.045,.065),(.285,.115,.18),'trim')
    d.curved('Spear_bridge_glass',[(-.16,.04,.02,.149,-.15),(-.055,.09,.028,.205,-.17),(.01,.065,.02,.175,-.16)],'glass')
    d.windows(-.275,.025,-.025,count=4,spacing=.029,side=True)
    d.beam('Spear_port_engine_cradle',(-.12,0,.29),(-.18,0,.39),.016,'dark')
    d.beam('Spear_starboard_engine_cradle',(.27,0,.30),(.18,0,.39),.016,'dark')
    d.beam('Spear_stern_crosshead',(-.20,0,.35),(.28,0,.35),.014,'trim')
    d.radiator(-.15,-.16,.12,width=.16,length=.13,rows=4)


def roaming_kite(d):
    """Wide diamond sail, a short starboard pressure pod and low port cargo mass."""
    d.curved('Kite_short_starboard_keel',[(-.34,.04,.07,-.025,.13),(-.18,.22,.22,.015,.15),(.05,.25,.27,.025,.15),(.26,.22,.22,.015,.12),(.39,.29,.17,0,0)],'hull')
    d.curved('Kite_low_port_cargo_pod',[(-.06,.07,.10,-.20,-.14),(.05,.21,.24,-.22,-.16),(.23,.20,.24,-.20,-.14),(.32,.09,.12,-.11,-.08)],'secondary')
    d.curved('Kite_pressure_pod_dark_waist',[(-.12,.22,.035,.01,.155),(.06,.258,.04,.015,.15),(.22,.22,.03,.005,.125)],'dark')
    d.block('Kite_port_cargo_airlock',(.065,.055,.07),(-.15,-.075,.17),'trim')
    d.wing('Kite_large_port_diamond_sail',[(-.45,-.10),(-.22,-.40),(.035,-.075),(-.17,.25)],.105,.025,'paint')
    d.wing('Kite_inner_graphite_sail',[(-.36,-.10),(-.215,-.30),(-.025,-.075),(-.16,.16)],.123,.010,'ceramic')
    d.truss((-.44,.04,-.095),(-.21,.04,-.38),.022,3)
    d.truss((-.44,.04,-.095),(-.17,.04,.25),.022,3)
    d.beam('Kite_diamond_main_spar',(-.21,.045,-.38),(-.17,.045,.25),.010,'trim')
    d.truss((.36,0,-.25),(.36,0,.29),.028,4)
    d.beam('Kite_forward_outrigger_cross',(.16,0,-.20),(.36,0,-.20),.010,'secondary')
    d.beam('Kite_rear_outrigger_cross',(.15,0,.23),(.36,0,.23),.012,'secondary')
    d.fin('Kite_starboard_counter_sail',[(0,-.23),(.22,-.10),(.20,.16),(.035,.28)],.40,.018,'trim')
    d.curved('Kite_bridge_canopy',[(-.13,.08,.05,.15,.15),(-.015,.15,.10,.20,.15),(.11,.10,.065,.14,.13)],'glass')
    d.windows(.285,.045,.035,count=4,spacing=.025,side=True)
    d.beam('Kite_aft_port_engine_support',(-.12,-.14,.26),(-.18,0,.39),.017,'dark')
    d.beam('Kite_aft_starboard_engine_support',(.14,0,.27),(.18,0,.39),.017,'dark')
    d.radiator(.14,-.14,.19,width=.14,length=.14,rows=4)


def roaming_tempest(d):
    """One exposed eccentric spine, a single tall sail and a short reactor mass."""
    d.truss((-.10,0,-.43),(-.10,0,.36),.045,7)
    d.beam('Tempest_ventral_backbone',(-.10,-.105,-.41),(-.10,-.105,.34),.012,'dark')
    d.loft('Tempest_compact_forward_pressure_head',[(-.47,.035,.07,-.04,-.10),(-.35,.17,.23,-.055,-.10),(-.21,.15,.20,-.05,-.10),(-.17,.09,.11,-.04,-.10)],'hull',.14)
    d.loft('Tempest_short_stern_service_body',[(.19,.12,.15,-.045,-.10),(.27,.22,.24,-.04,-.09),(.37,.25,.18,-.01,-.05)],'secondary',.13)
    d.fin('Tempest_single_port_sail',[(-.06,-.29),(.35,-.15),(.43,.075),(.25,.26),(-.035,.31)],-.34,.026,'paint')
    d.fin('Tempest_graphite_sail_membrane',[(.025,-.22),(.28,-.115),(.35,.055),(.20,.19),(.035,.235)],-.357,.010,'ceramic')
    d.beam('Tempest_sail_forward_edge',(-.34,-.06,-.29),(-.34,.35,-.15),.007,'trim')
    d.beam('Tempest_sail_upper_edge',(-.34,.35,-.15),(-.34,.43,.075),.007,'trim')
    d.beam('Tempest_sail_aft_edge',(-.34,.43,.075),(-.34,.25,.26),.007,'trim')
    d.beam('Tempest_sail_lower_edge',(-.34,-.035,.31),(-.34,-.06,-.29),.008,'dark')
    d.curved('Tempest_short_starboard_reactor',[(-.055,.12,.18,-.08,.29),(.015,.26,.37,-.08,.31),(.14,.25,.38,-.075,.315),(.24,.13,.20,-.06,.28)],'secondary')
    d.ring('Tempest_reactor_restrained_hoop',(.31,-.075,.08),.135,.20,.018,'dark',32)
    d.ring('Tempest_reactor_service_seal',(.30,-.075,.19),.095,.145,.012,'trim',28)
    d.truss((-.34,-.025,-.11),(.37,-.025,-.11),.026,5)
    d.truss((-.34,-.025,.235),(.36,-.025,.235),.026,5)
    d.beam('Tempest_reactor_forward_suspension',(.29,-.09,-.025),(.23,-.025,-.11),.016,'secondary')
    d.beam('Tempest_reactor_rear_suspension',(.30,-.09,.19),(.23,-.025,.235),.016,'secondary')
    d.windows(-.19,-.015,-.285,count=4,spacing=.024,side=True)
    d.block('Tempest_forward_navigation_recess',(.075,.022,.07),(-.10,.068,-.30),'ceramic')
    d.beam('Tempest_stern_power_bridge',(-.24,0,.35),(.24,0,.35),.019,'secondary')
    d.radiator(.31,-.30,.095,width=.15,length=.16,rows=4)


BUILDERS = {
    'cruiser_council_sentinel': council_sentinel,
    'battleship_council_aegis': council_aegis,
    'support_council_choir': council_choir,
    'destroyer_forge_hammer': forge_hammer,
    'cruiser_forge_citadel': forge_citadel,
    'battleship_forge_ironwall': forge_ironwall,
    'destroyer_roaming_spear': roaming_spear,
    'cruiser_roaming_kite': roaming_kite,
    'battleship_roaming_tempest': roaming_tempest,
}
