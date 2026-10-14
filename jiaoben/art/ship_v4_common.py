"""Ten individually composed original hulls. See doc/70 for design decisions."""
import math


def shuttle(d):
    # A compact lifting-body courier with a split nose and swept shoulders.
    d.curved('Courier_pressure_body',[(-.46,.035,.055,-.04,0),(-.28,.25,.23,0,0),(.02,.40,.40,.03,0),(.24,.26,.32,.02,0),(.38,.12,.15,0,0)])
    d.curved('Cockpit_brow',[(-.29,.16,.075,.13,0),(-.10,.23,.11,.235,0),(.08,.17,.08,.25,0)],'glass')
    for s in [-1,1]:
        d.wing('Swept_courier_shoulders',[(s*.12,-.22),(s*.47,.12),(s*.42,.27),(s*.22,.17)],-.03,.07,'paint',.14)
        d.loft('Fore_sensor_prong',[(-.48,.035,.04,-.055,s*.06),(-.22,.085,.10,-.04,s*.10)],'secondary')
        d.radiator(s*.29,.105,.15,.09,.11,5)
        d.fin('Aft_canted_stabilizer',[(.10,.24),(.43,.34),(.32,.42),(.02,.32)],s*.26,.018,'trim')
    d.block('Belly_docking_shoe',(.15,.07,.20),(0,-.24,.05),'dark')
    d.windows(0,.19,-.10,4,.035)


def lantern(d):
    # Survey frigate: one protected offset bridge, a visibly open sensor fork.
    d.curved('Survey_main_cowl',[(-.25,.12,.16,.01,.05),(-.06,.36,.35,.015,.03),(.20,.43,.40,0,0),(.38,.25,.20,0,0)])
    for s in [-1,1]:
        d.curved('Sensor_fork',[(-.47,.022,.04,.02,s*.29),(-.35,.07,.13,.03,s*.31),(-.08,.13,.23,.02,s*.24),(.18,.18,.28,0,s*.16)],'hull')
        d.wing('Diagonal_structural_shoulder',[(s*.08,-.06),(s*.44,.06),(s*.48,.16),(s*.14,.23)],-.09,.065,'paint')
        d.radiator(s*.30,.08,.10,.10,.10,6)
    d.ring('Recessed_forward_sensor',(0,-.04,-.18),.12,.22,.018,'dark',40)
    d.ring('Sensor_focus_coil',(0,-.04,-.20),.095,.175,.008,'trim',40)
    d.curved('Offset_observation_bridge',[(-.12,.09,.04,.28,.10),(.02,.13,.12,.32,.10),(.12,.09,.04,.29,.08)],'paint')
    d.windows(.10,.34,-.08,5,.019)
    d.fin('Survey_dorsal_radiator',[(.14,.11),(.47,.19),(.42,.30),(.10,.25)],-.08,.014,'ceramic')
    d.beam('Sensor_mast',(-.16,.16,.14),(-.22,.46,.17),.004,'trim')


def kestrel(d):
    # Fast asymmetric raider: long port blade, short starboard control pod.
    d.loft('Raider_spine',[(-.40,.05,.07,-.01,-.04),(-.17,.17,.19,0,-.03),(.19,.27,.30,0,0),(.37,.18,.18,0,0)],'secondary')
    d.loft('Port_attack_blade',[(-.49,.018,.035,.02,-.30),(-.31,.11,.16,.025,-.33),(.02,.17,.27,.03,-.27),(.24,.16,.21,0,-.20)],'hull')
    d.loft('Starboard_bridge_pod',[(-.17,.035,.07,.08,.31),(-.06,.14,.24,.10,.35),(.18,.14,.26,.06,.30),(.29,.09,.11,.02,.18)],'paint')
    d.truss((-.26,-.02,-.16),(.29,-.02,-.02),.04,5)
    d.truss((-.23,.02,.13),(.27,.02,.12),.035,5)
    d.wing('Port_swept_spar',[(-.21,-.09),(-.49,.16),(-.44,.23),(-.17,.16)],-.10,.03,'trim')
    d.fin('Starboard_heat_sail',[(.02,.05),(.46,.20),(.35,.33),(-.06,.22)],.35,.009,'ceramic')
    d.windows(.35,.17,-.055,4,.017)
    d.radiator(-.27,.18,.11,.10,.11,7)
    d.beam('Fore_target_antenna',(-.32,.12,-.31),(-.40,.17,-.44),.003,'dark')


def miner(d):
    # An open horseshoe ore processor. Empty central loading throat matters.
    d.loft('Aft_refinery_transom',[(.08,.66,.33,-.035,0),(.22,.80,.45,-.01,0),(.34,.46,.29,0,0)],'secondary')
    for s in [-1,1]:
        d.loft('Excavator_arm',[(-.47,.04,.09,-.06,s*.34),(-.31,.15,.25,-.04,s*.36),(.09,.20,.39,-.02,s*.31),(.23,.19,.35,0,s*.25)],'hull')
        d.wing('Sacrificial_side_armor',[(s*.28,-.29),(s*.48,-.22),(s*.47,.17),(s*.31,.23)],.055,.075,'paint')
        d.beam('Mining_head_actuator',(s*.36,-.02,-.21),(s*.26,-.08,-.38),.018,'trim')
        d.ring('Ore_grapple_jaw',(s*.27,-.09,-.39),.045,.085,.04,'dark',24)
        d.truss((s*.30,-.20,-.26),(s*.28,-.20,.10),.032,5)
        d.radiator(s*.32,.24,.09,.13,.13,7)
    d.block('Recessed_ore_loading_bay',(.34,.17,.26),(0,-.17,.10),'dark')
    d.loft('Elevated_control_bridge',[(-.03,.18,.10,.30,0),(.08,.27,.15,.35,0),(.18,.15,.08,.29,0)],'paint')
    d.windows(0,.36,-.028,10,.018)
    d.truss((-.25,.11,.14),(-.25,.38,-.05),.02,3)
    d.beam('Loading_crane_jib',(-.25,.38,-.05),(.10,.38,-.22),.012,'warning')
    d.beam('Loading_hook',(.10,.38,-.22),(.10,.09,-.22),.003,'dark')
    d.fin('Ventral_sorting_keel',[(-.08,.02),(-.47,.11),(-.39,.24),(-.08,.26)],0,.12,'dark')


def raptor(d):
    # A naval axe: high rear superstructure and a low forward rail keel.
    d.loft('Artillery_lower_keel',[(-.49,.05,.07,-.19,0),(-.28,.20,.15,-.18,0),(.08,.32,.25,-.12,0),(.34,.28,.34,0,0)],'secondary')
    d.loft('Raised_armor_back',[(-.16,.20,.22,.10,0),(.03,.53,.44,.20,0),(.24,.60,.50,.17,0),(.35,.29,.25,.02,0)],'hull')
    for s in [-1,1]:
        d.wing('Oblique_broadside_armor',[(s*.13,-.13),(s*.39,.00),(s*.46,.27),(s*.27,.32)],-.04,.20,'paint',.09)
        d.loft('Fore_outrigger_gun_deck',[(-.42,.06,.10,.08,s*.24),(-.28,.12,.17,.10,s*.25),(.07,.14,.22,.08,s*.27)],'hull')
        d.radiator(s*.28,.30,.17,.10,.16,9)
        for z in [.00,.08,.16]:d.block('Broadside_dark_recess',(.01,.09,.045),(s*.306,.08,z),'dark')
    d.fin('Dorsal_command_tower',[(.17,.04),(.48,.13),(.42,.24),(.14,.25)],0,.10,'trim')
    d.windows(0,.40,.09,7,.012)
    d.fin('Forward_ballistic_keel',[(-.17,-.45),(-.43,-.31),(-.30,.08),(-.09,.15)],0,.045,'dark')


def horizon(d):
    # A broad tapered manta with a hollow waist and forward protective horns.
    d.curved('Manta_command_core',[(-.43,.045,.06,-.03,0),(-.26,.18,.18,0,0),(-.02,.36,.42,.04,0),(.20,.31,.38,.02,0),(.38,.15,.14,0,0)])
    for s in [-1,1]:
        d.curved('Swept_lateral_shell',[(-.39,.025,.035,.02,s*.22),(-.20,.10,.15,.04,s*.32),(.04,.23,.30,.02,s*.38),(.22,.15,.20,0,s*.31),(.31,.035,.05,-.02,s*.22)],'hull')
        d.wing('Manta_upper_shoulder',[(s*.10,-.15),(s*.32,-.08),(s*.46,.13),(s*.34,.23),(s*.16,.13)],.13,.045,'paint',.07)
        d.truss((s*.13,-.09,-.03),(s*.34,-.10,.08),.035,4)
        d.radiator(s*.30,.19,.15,.10,.09,7)
        d.loft('Long_forward_sensor_spear',[(-.47,.01,.025,-.06,s*.30),(-.28,.04,.055,-.04,s*.30),(-.12,.06,.08,-.01,s*.26)],'trim')
    d.loft('Low_armored_command_gallery',[(-.10,.09,.055,.245,-.025),(.02,.16,.08,.27,-.025),(.16,.13,.055,.24,-.025)],'secondary')
    d.windows(-.025,.28,-.055,11,.011)
    d.loft('Offset_mission_bay',[(.00,.11,.13,-.10,.34),(.14,.18,.21,-.09,.35),(.27,.11,.13,-.06,.29)],'secondary')
    d.block('Recessed_shuttle_bay',(.095,.072,.003),(.34,-.105,.001),'dark')
    d.windows(.35,-.015,.001,6,.009)
    d.ring('Ventral_navigation_array',(0,-.25,.03),.12,.065,.02,'dark',40,axis='y')
    d.beam('Short_offset_sensor_mast',(-.08,.25,.17),(-.08,.36,.17),.003,'dark')
    d.beam('Cross_sensor_yard',(-.15,.36,.17),(-.02,.36,.17),.0025,'trim')


def bastion(d):
    # Split fortress prow with thick stacked armor and recessed broadside bays.
    d.loft('Fortress_reactor_keel',[(-.32,.18,.20,-.12,0),(-.08,.44,.40,-.06,0),(.21,.48,.53,0,0),(.36,.32,.30,0,0)],'dark')
    for s in [-1,1]:
        d.loft('Split_battleship_prow',[(-.47,.035,.08,.00,s*.19),(-.30,.21,.32,.015,s*.25),(-.03,.27,.49,.02,s*.28),(.24,.28,.43,0,s*.26),(.35,.14,.23,0,s*.20)],'hull')
        d.wing('Layered_broadside_belt',[(s*.18,-.23),(s*.43,-.11),(s*.49,.16),(s*.42,.29),(s*.23,.23)],.16,.09,'paint')
        d.wing('Lower_spaced_armor',[(s*.23,-.20),(s*.46,-.04),(s*.45,.21),(s*.25,.26)],-.22,.07,'secondary')
        for z in [-.05,.025,.10,.175]:
            d.block('Recessed_gun_port',(.012,.13,.045),(s*.414,-.01,z),'dark')
            d.beam('Broadside_port_liner',(s*.42,-.015,z-.018),(s*.42,-.015,z+.018),.006,'trim')
        d.radiator(s*.28,.29,.17,.13,.14,9)
    d.loft('Command_citadel',[(-.04,.13,.10,.29,0),(.08,.24,.24,.35,0),(.22,.15,.14,.31,0)],'trim')
    d.windows(0,.40,.015,15,.011)
    d.fin('Ventral_armored_rudder',[(-.20,-.10),(-.48,.02),(-.40,.26),(-.16,.32)],0,.09,'secondary')
    d.beam('Heavy_dorsal_mast',(.04,.39,.17),(.04,.49,.23),.0035,'dark')


def caravan(d):
    # Offset bridge on a keel with eight round pressure tanks and visible voids.
    d.loft('Longitudinal_freight_keel',[(-.45,.09,.14,-.06,0),(-.27,.13,.20,-.04,0),(.21,.15,.22,-.04,0),(.38,.28,.30,0,0)],'dark')
    for s in [-1,1]:
        for z in [-.28,-.02,.24]:
            d.beam('Pressure_cargo_tank',(s*.30,-.03,z-.105),(s*.30,-.03,z+.095),.115,'secondary',radius_end=.104,segments=24)
            for zz in [z-.08,z+.07]:d.ring('Tank_capture_hoop',(s*.30,-.03,zz),.123,.123*d.dim.x/d.dim.y,.015,'trim',24)
            d.truss((0,-.15,z),(s*.30,-.15,z),.03,4)
            d.beam('Outer_safety_rail_cradle',(s*.45,-.21,z),(s*.30,-.15,z),.009,'trim')
        d.truss((s*.45,-.21,-.37),(s*.45,-.21,.34),.025,8)
        d.wing('Freight_shoulder_shield',[(s*.13,.19),(s*.40,.22),(s*.38,.34),(s*.19,.37)],.19,.035,'paint')
    d.loft('Offset_pilot_gondola',[(-.35,.035,.07,.25,.22),(-.24,.13,.16,.29,.22),(-.09,.12,.13,.27,.20)],'hull')
    d.windows(.22,.32,-.30,7,.011)
    d.truss((.17,.03,-.21),(.20,.24,-.21),.015,3)
    d.fin('Freighter_docking_keel',[(-.13,-.24),(-.46,-.11),(-.43,.17),(-.13,.29)],-.01,.045,'secondary')
    d.fin('Tall_radio_flag',[(.18,-.04),(.47,.07),(.42,.18),(.12,.10)],-.12,.009,'ceramic')


def weaver(d):
    # Open crescent laboratory: lateral wings curl forward around a repair bay.
    d.curved('Laboratory_central_hull',[(-.32,.04,.06,-.02,0),(-.13,.20,.23,0,0),(.11,.28,.39,.05,0),(.34,.22,.20,0,0)],'hull')
    for s in [-1,1]:
        d.curved('Crescent_laboratory_wing',[(-.41,.025,.04,-.02,s*.25),(-.25,.09,.15,.00,s*.38),(-.02,.19,.30,.035,s*.39),(.17,.18,.26,.02,s*.27),(.29,.06,.10,0,s*.14)],'paint')
        d.truss((s*.09,-.14,.10),(s*.35,-.14,-.03),.035,5)
        d.ring('Repair_projector',(s*.30,-.04,-.28),.055,.11,.02,'trim',32)
        d.beam('Repair_boom',(s*.35,-.08,-.12),(s*.27,-.09,-.34),.010,'secondary')
        d.radiator(s*.32,.20,.02,.10,.14,8)
    d.ring('Open_communication_torus',(0,.28,.08),.18,.12,.023,'trim',48,axis='y')
    d.ring('Dish_inset',(0,.28,.08),.145,.095,.009,'dark',48,axis='y')
    d.beam('Dish_feed',(0,.19,.08),(0,.44,.08),.008,'trim')
    d.curved('Forward_control_nodule',[(-.25,.11,.07,.19,0),(-.15,.16,.13,.24,0),(-.03,.09,.04,.20,0)],'hull')
    d.windows(0,.255,-.19,8,.013)
    d.fin('Ventral_recovery_cradle',[(-.12,-.15),(-.45,-.02),(-.40,.22),(-.10,.28)],0,.065,'dark')


def silent(d):
    # An uncrewed split tri-lobed relic with a clear central void, no cockpit.
    for s in [-1,1]:
        d.curved('Relic_outer_talon',[(-.48,.008,.025,-.06,s*.09),(-.29,.07,.13,.01,s*.32),(.00,.17,.38,.03,s*.38),(.25,.11,.28,.02,s*.24),(.36,.04,.09,0,s*.18)],'hull',5)
        d.curved('Inner_relic_layer',[(-.33,.015,.04,-.11,s*.10),(-.12,.065,.16,-.14,s*.23),(.14,.09,.22,-.08,s*.21)],'ceramic',5)
        d.fin('Relic_blade',[(.05,-.02),(.46,.04),(.31,.26),(-.02,.32)],s*.30,.018,'trim')
        d.truss((s*.15,-.19,.20),(s*.30,-.14,-.08),.016,5)
    d.ring('Relic_zero_point_iris',(0,-.09,.12),.13,.19,.033,'dark',48)
    d.ring('Relic_iris_trim',(0,-.09,.10),.105,.155,.008,'trim',48)
    d.loft('Central_ventral_shard',[(-.30,.015,.04,-.25,0),(-.01,.11,.20,-.35,0),(.25,.075,.09,-.25,0)],'paint')
    d.beam('Iris_low_power_core',(0,-.09,.115),(0,-.09,.109),.025,'glow',segments=24)
    for z in [-.07,.00,.07]:
        d.beam('Relic_transverse_conduit',(-.23,-.12,z),(.23,-.12,z+.035),.004,'secondary')


BUILDERS={'shuttle_swift':shuttle,'frigate_lantern':lantern,'frigate_kestrel':kestrel,
          'miner_anvil':miner,'destroyer_raptor':raptor,'cruiser_horizon':horizon,
          'battleship_bastion':bastion,'transport_caravan':caravan,'support_weaver':weaver,
          'enemy_silent':silent}
