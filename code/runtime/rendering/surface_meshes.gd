class_name XJSurfaceMeshes
extends RefCounted
## Presentation meshes only. Original collision, anchors and source resources stay intact.
static var _boxes: Dictionary = {}
static var _debris: Dictionary = {}
static var _ores: Dictionary = {}

static func chamfer_box(source: BoxMesh) -> ArrayMesh:
	if source == null: return null
	var dimensions: Vector3 = source.size
	if _boxes.has(dimensions): return _boxes[dimensions]
	var half: Vector3 = dimensions * 0.5
	var bevel: float = minf(dimensions.x, minf(dimensions.y, dimensions.z)) * 0.08
	var inner: Vector3 = half - Vector3.ONE * bevel
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six flat faces, twelve edge bevels and eight triangular corner bevels.
	for axis: int in range(3):
		var first: int = (axis + 1) % 3
		var second: int = (axis + 2) % 3
		for sign_value: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var corners: Array[Vector3] = []
			for coordinates: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * sign_value
				point[first] = inner[first] * coordinates.x
				point[second] = inner[second] * coordinates.y
				corners.append(point)
			_quad(tool, corners, normal)
	for first: int in range(3):
		for second: int in range(first + 1, 3):
			var along: int = 3 - first - second
			for a: float in [-1.0, 1.0]:
				for b: float in [-1.0, 1.0]:
					var normal := Vector3.ZERO
					normal[first] = a
					normal[second] = b
					var corners: Array[Vector3] = []
					for endpoint: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
						var point := Vector3.ZERO
						point[along] = inner[along] * endpoint.x
						point[first] = (half[first] if endpoint.y == 0 else inner[first]) * a
						point[second] = (inner[second] if endpoint.y == 0 else half[second]) * b
						corners.append(point)
					_quad(tool, corners, normal.normalized())
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var normal := Vector3(x, y, z).normalized()
				_triangle(tool, Vector3(half.x * x, inner.y * y, inner.z * z), Vector3(inner.x * x, half.y * y, inner.z * z), Vector3(inner.x * x, inner.y * y, half.z * z), normal)
	var result: ArrayMesh = tool.commit()
	result.resource_name = "materials_v1_chamfer_box"
	_boxes[dimensions] = result
	return result

static func irregular_debris(source: SphereMesh) -> ArrayMesh:
	if source == null: return null
	var bounds: AABB = source.get_aabb()
	var half: Vector3 = bounds.size * 0.5
	if _debris.has(half): return _debris[half]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cardinal vertices retain the source's exact axis extrema. All other
	# vertices are deterministically inset; the collision sphere is untouched.
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				_debris_triangle(tool, Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z), half, 2)
	var result: ArrayMesh = tool.commit()
	result.resource_name = "materials_v1_irregular_debris"
	_debris[half] = result
	return result

static func irregular_ore(bounds: AABB) -> ArrayMesh:
	var identity: String = str(bounds.position) + ":" + str(bounds.size)
	if _ores.has(identity): return _ores[identity]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				_ore_triangle(tool, Vector3(x, 0, 0), Vector3(0, y, 0), Vector3(0, 0, z), bounds, 4)
	var result: ArrayMesh = tool.commit()
	result.resource_name = "materials_v1_irregular_ore"
	_ores[identity] = result
	return result

static func _ore_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, bounds: AABB, remaining: int) -> void:
	if remaining > 0:
		var ab: Vector3 = (a + b).normalized()
		var bc: Vector3 = (b + c).normalized()
		var ca: Vector3 = (c + a).normalized()
		_ore_triangle(tool, a, ab, ca, bounds, remaining - 1)
		_ore_triangle(tool, ab, b, bc, bounds, remaining - 1)
		_ore_triangle(tool, ca, bc, c, bounds, remaining - 1)
		_ore_triangle(tool, ab, bc, ca, bounds, remaining - 1)
		return
	var points: Array[Vector3] = [_ore_vertex(a, bounds), _ore_vertex(b, bounds), _ore_vertex(c, bounds)]
	var center: Vector3 = bounds.get_center()
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if normal.dot(points[0] + points[1] + points[2] - center * 3.0) < 0.0: normal = -normal
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0.0:
		var second: Vector3 = points[1]
		points[1] = points[2]
		points[2] = second
	var half: Vector3 = bounds.size * 0.5
	for point: Vector3 in points:
		var direction: Vector3 = ((point - center) / half).normalized()
		var tangent: Vector3 = direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
		var bitangent: Vector3 = direction.cross(tangent).normalized()
		var du: Vector3 = _ore_vertex((direction + tangent * 0.002).normalized(), bounds) - point
		var dv: Vector3 = _ore_vertex((direction + bitangent * 0.002).normalized(), bounds) - point
		var continuous: Vector3 = du.cross(dv).normalized()
		if continuous.dot(point - center) < 0.0: continuous = -continuous
		# Use the deformed rock's own surface gradient. Radial sphere normals
		# flatten cavities; per-triangle normals turn geology into a polygon toy.
		var shading_normal: Vector3 = (normal * 0.12 + continuous * 0.88).normalized()
		# At a narrow procedural crease the analytic gradient may cross this
		# finite triangle's tangent plane. Keep the shading normal in its
		# outward hemisphere so smooth lighting cannot invert a visible facet.
		var alignment: float = shading_normal.dot(normal)
		if alignment < 0.05: shading_normal = (shading_normal + normal * (0.05 - alignment)).normalized()
		tool.set_normal(shading_normal)
		tool.add_vertex(point)

static func _ore_vertex(direction: Vector3, bounds: AABB) -> Vector3:
	var cardinal: float = maxf(absf(direction.x), maxf(absf(direction.y), absf(direction.z)))
	var weight: float = clampf((1.0 - cardinal) / 0.42265, 0.0, 1.0)
	var seed_value: float = bounds.position.dot(Vector3(0.13, 0.19, 0.23)) + bounds.size.dot(Vector3(0.17, 0.11, 0.07))
	var variation: float = 0.5 + 0.5 * sin(direction.dot(Vector3(7.1, 11.3, 5.9)) + seed_value + sin(direction.dot(Vector3(13.7, -4.3, 9.1)) - seed_value))
	return bounds.get_center() + direction * bounds.size * 0.5 * (1.0 - 0.28 * weight * (0.35 + 0.65 * variation))

static func _debris_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, half: Vector3, remaining: int) -> void:
	if remaining > 0:
		var ab: Vector3 = (a + b).normalized()
		var bc: Vector3 = (b + c).normalized()
		var ca: Vector3 = (c + a).normalized()
		_debris_triangle(tool, a, ab, ca, half, remaining - 1)
		_debris_triangle(tool, ab, b, bc, half, remaining - 1)
		_debris_triangle(tool, ca, bc, c, half, remaining - 1)
		_debris_triangle(tool, ab, bc, ca, half, remaining - 1)
		return
	var p: Vector3 = _debris_vertex(a, half)
	var q: Vector3 = _debris_vertex(b, half)
	var r: Vector3 = _debris_vertex(c, half)
	var normal: Vector3 = (q - p).cross(r - p).normalized()
	if normal.dot(p + q + r) < 0.0: normal = -normal
	_triangle(tool, p, q, r, normal)

static func _debris_vertex(direction: Vector3, half: Vector3) -> Vector3:
	var cardinal: float = maxf(absf(direction.x), maxf(absf(direction.y), absf(direction.z)))
	var weight: float = clampf((1.0 - cardinal) / 0.42265, 0.0, 1.0)
	var variation: float = 0.5 + 0.5 * sin(direction.dot(Vector3(7.1, 11.3, 5.9)) + sin(direction.dot(Vector3(13.7, -4.3, 9.1))))
	return direction * half * (1.0 - 0.25 * weight * (0.35 + 0.65 * variation))

static func _quad(tool: SurfaceTool, corners: Array[Vector3], normal: Vector3) -> void:
	_triangle(tool, corners[0], corners[1], corners[2], normal)
	_triangle(tool, corners[0], corners[2], corners[3], normal)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot uses clockwise front faces. Supply explicit outward facet normals.
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		points[1] = c
		points[2] = b
	for point: Vector3 in points:
		tool.set_normal(normal)
		tool.add_vertex(point)
