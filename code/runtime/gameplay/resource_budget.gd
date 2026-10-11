extends RefCounted
## Shared resource arithmetic for live paid cycles and read-only fit analysis.
static func blocked(energy: float,heat: float,overheated: bool,heat_max: float,cost_energy: float,cost_heat: float) -> String:
	if overheated or heat+cost_heat>heat_max: return "热量已达到限制"
	if energy<cost_energy: return "能量不足"
	return ""
static func advance(ship: RefCounted,metrics: Dictionary,delta: float,unlock_ratio: float) -> void:
	ship.energy=minf(float(metrics.energy_max),ship.energy+float(metrics.energy_recharge)*delta)
	ship.heat=maxf(0.0,ship.heat-float(metrics.heat_cooling)*delta)
	if ship.heat<=float(metrics.heat_max)*unlock_ratio:ship.overheated=false
