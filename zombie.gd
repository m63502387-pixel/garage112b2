extends StaticBody3D
## Зомби: идёт по улице, колотит в дверь гаража, входит если дверь выбита/открыта

const Fig = preload("res://figure.gd")

var main
var mode := "hunt"          # pass | door | hunt | leave
var hp := 3.0
var speed := 2.0
var pass_dir := 0.0
var attention := 25.0
var bash_cd := 0.0
var atk_cd := 0.0
var door_slot := 0.0
var leave_dir := 1.0
var ph := 0.0
var tt := 0.0
var moving := false
var bashing := false
var dead := false
var fig_root: Node3D
var legs: Array = []
var arms: Array = []


func setup(m, md: String, spd: float, pdir: float) -> void:
	main = m
	mode = md
	speed = spd
	pass_dir = pdir
	door_slot = randf_range(-1.0, 1.0)
	attention = randf_range(20.0, 30.0)
	add_to_group("zombies")
	set_meta("zombie", true)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	var shirt := Color(randf_range(0.2, 0.45), randf_range(0.15, 0.3), randf_range(0.15, 0.3))
	var f: Dictionary = Fig.build(true, shirt, Color(0.42, 0.58, 0.38))
	fig_root = f["root"]
	legs = f["legs"]
	arms = f["arms"]
	add_child(fig_root)


func hit(dmg: float) -> void:
	if dead:
		return
	hp -= dmg
	if hp <= 0.0:
		dead = true
		collision_layer = 0
		remove_from_group("zombies")
		main.on_zombie_killed()
		var tw := create_tween()
		tw.tween_property(fig_root, "rotation_degrees:x", -90.0, 0.4)
		tw.tween_interval(1.5)
		tw.tween_callback(queue_free)


func _gate(tgt: Vector3, inside_s: bool, inside_t: bool) -> Vector3:
	if inside_s == inside_t:
		return tgt
	if not inside_s:
		if global_position.z > 0.8:
			return Vector3(0.0, 0.0, 0.5)
		return Vector3(0.0, 0.0, -0.7)
	if global_position.z < -0.7:
		return Vector3(0.0, 0.0, -0.4)
	return Vector3(0.0, 0.0, 1.0)


func _move_dir(dir: Vector3, spd: float, delta: float) -> void:
	global_position += dir * spd * delta
	rotation.y = atan2(-dir.x, -dir.z)
	ph += delta * spd * 3.0
	moving = true


func _move_to(tgt: Vector3, spd: float, delta: float) -> void:
	var dv := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
	if dv.length() < 0.05:
		return
	_move_dir(dv.normalized(), spd, delta)


func _face(tgt: Vector3) -> void:
	var dv := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
	if dv.length() > 0.01:
		rotation.y = atan2(-dv.x, -dv.z)


func _animate(delta: float) -> void:
	tt += delta
	var sw: float = sin(ph) * 0.7 if moving else 0.0
	legs[0].rotation.x = sw
	legs[1].rotation.x = -sw
	var a: float = 80.0 + sin(ph) * 6.0
	if bashing:
		a = 85.0 + sin(tt * 20.0) * 25.0
	arms[0].rotation_degrees.x = a
	arms[1].rotation_degrees.x = a


func _process(delta: float) -> void:
	if dead or main.game_over:
		return
	var p: Vector3 = main.player.global_position
	var gp: Vector3 = global_position
	var d: float = Vector2(p.x - gp.x, p.z - gp.z).length()
	bashing = false
	moving = false
	match mode:
		"pass":
			_move_dir(Vector3(pass_dir, 0.0, 0.0), speed, delta)
			if absf(gp.x) > 48.0:
				queue_free()
				return
			if p.z > 0.4 and d < 7.0:
				mode = "hunt"
		"hunt":
			var inside_p: bool = p.z < -0.2
			var inside_s: bool = gp.z < -0.2
			if (not inside_s) and inside_p and not main.door_open:
				mode = "door"
				return
			if d > 0.8:
				_move_to(_gate(p, inside_s, inside_p), speed, delta)
			atk_cd -= delta
			if d < 1.0 and atk_cd <= 0.0:
				atk_cd = 0.9
				main.hurt(9.0)
		"door":
			if main.door_open or p.z > 0.4:
				mode = "hunt"
				return
			var spot := Vector3(door_slot, 0.0, 1.15)
			if gp.distance_to(spot) > 0.3:
				_move_to(spot, speed, delta)
			else:
				_face(Vector3(door_slot, 0.0, 0.0))
				bashing = true
				bash_cd -= delta
				if bash_cd <= 0.0:
					bash_cd = 0.8
					main.door_hit(1.5)
				attention -= delta
				if attention <= 0.0:
					mode = "leave"
					leave_dir = 1.0 if gp.x >= 0.0 else -1.0
		"leave":
			_move_dir(Vector3(leave_dir, 0.0, 0.0), speed, delta)
			if absf(gp.x) > 48.0:
				queue_free()
				return
			if p.z > 0.4 and d < 5.0:
				mode = "hunt"
	_animate(delta)
