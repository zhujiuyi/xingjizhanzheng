class_name XJSpaceUnits
extends RefCounted
## Physical unit conversion only. Gameplay distances remain metres in SQLite.
const METRES_PER_AU: float = 149597870700.0

static func distance(metres: float) -> String:
	if not is_finite(metres) or metres < 0.0: return "—"
	if metres >= METRES_PER_AU * 0.001:
		var au: float = metres / METRES_PER_AU
		return ("%.3f AU" if au < 1.0 else "%.2f AU") % au
	if metres >= 1000.0:
		var km: float = metres / 1000.0
		return ("%.1f km" if km < 100.0 else "%.0f km") % km
	return "%.0f m" % metres

static func speed(metres_per_second: float) -> String:
	if not is_finite(metres_per_second) or metres_per_second < 0.0: return "—"
	if metres_per_second >= METRES_PER_AU * 0.001:
		return "%.3f AU/s" % (metres_per_second / METRES_PER_AU)
	if metres_per_second >= 1000.0: return "%.1f km/s" % (metres_per_second / 1000.0)
	return "%.1f m/s" % metres_per_second
