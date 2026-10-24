extends RefCounted
## Блочные человечки (люди и зомби)

static func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func build(zombie: bool, shirt: Color, skin: Color) -> Dictionary:
	var root := Node3D.new()
	_box(root, Vector3(0, 1.05, 0), Vector3(0.5, 0.7, 0.26), shirt)
	_box(root, Vector3(0, 1.6, 0), Vector3(0.32, 0.32, 0.32), skin)
	var legs: Array = []
	for sx in [-0.13, 0.13]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.7, 0)
		root.add_child(hip)
		_box(hip, Vector3(0, -0.35, 0), Vector3(0.2, 0.7, 0.2), Color(0.12, 0.14, 0.2))
		legs.append(hip)
	var arms: Array = []
	for sx in [-0.36, 0.36]:
		var sh := Node3D.new()
		sh.position = Vector3(sx, 1.38, 0)
		root.add_child(sh)
		_box(sh, Vector3(0, -0.3, 0), Vector3(0.15, 0.6, 0.15), skin if zombie else shirt)
		if zombie:
			sh.rotation_degrees.x = 80.0   # руки вперёд
		arms.append(sh)
	return {"root": root, "legs": legs, "arms": arms}
